import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/database_initializer.dart';
import 'data/plano_repository.dart';
import 'data/sqlite_planify_repository.dart';
import 'domain/planner.dart';

part 'ui/screens/today_screen.dart';
part 'ui/screens/inbox_screen.dart';
part 'ui/screens/calendar_screen.dart';
part 'ui/screens/settings_screen.dart';
part 'ui/theme/app_theme.dart';
part 'ui/sheets/task_editor.dart';
part 'ui/sheets/planner_sheets.dart';
part 'ui/widgets/ui_helpers.dart';
part 'ui/screens/product_guide.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializePlanifyDatabase();
  runApp(const PlanoApp());
}

const _primary = Color(0xFF4F46E5);
const _primarySoft = Color(0xFFEEF0FF);
const _success = Color(0xFF10B981);
const _warning = Color(0xFFF59E0B);
const _danger = Color(0xFFEF4444);
const _ink = Color(0xFF111827);
const _muted = Color(0xFF6B7280);
const _canvas = Color(0xFFF7F7FB);
const _border = Color(0xFFE5E7EB);
class PlanoApp extends StatefulWidget {
  const PlanoApp({super.key, this.repository});

  final PlanoRepository? repository;

  @override
  State<PlanoApp> createState() => _PlanoAppState();
}

class _PlanoAppState extends State<PlanoApp> {
  bool _darkMode = false;
  TimeOfDay _workStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _workEnd = const TimeOfDay(hour: 18, minute: 0);
  late final PlanoRepository _repository =
      widget.repository ?? SqlitePlanifyRepository();
  final _tasks = <PlanoTask>[];
  DateTime _selectedDate = _dateOnly(DateTime.now());
  List<FixedEvent> _events = [];
  int _tabIndex = 0;
  List<PlanoTask>? _lastSnapshot;
  BuildContext? _appContext;
  bool _isLoading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final values = await Future.wait<Object>([
        _repository.loadTasks(),
        _repository.loadEvents(_selectedDate),
        _repository.loadWorkSchedule(),
        _repository.loadDarkMode(),
      ]);
      if (!mounted) return;
      final schedule = values[2] as WorkSchedule;
      setState(() {
        _tasks
          ..clear()
          ..addAll(values[0] as List<PlanoTask>);
        _events = values[1] as List<FixedEvent>;
        _workStart = _timeOfDayFromMinutes(schedule.startMinute);
        _workEnd = _timeOfDayFromMinutes(schedule.endMinute);
        _darkMode = values[3] as bool;
        _isLoading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = error;
      });
    }
  }

  Future<void> _selectDate(DateTime date) async {
    final selectedDate = _dateOnly(date);
    setState(() {
      _selectedDate = selectedDate;
    });
    try {
      final events = await _repository.loadEvents(selectedDate);
      if (!mounted || !_sameDay(_selectedDate, selectedDate)) return;
      setState(() => _events = events);
    } on Object catch (error) {
      if (mounted) {
        _showMessage('Impossible de charger les événements : $error');
      }
    }
  }

  Future<void> _setDarkMode(bool enabled) async {
    try {
      await _repository.saveDarkMode(enabled);
      if (mounted) setState(() => _darkMode = enabled);
    } on Object catch (error) {
      _showMessage('Impossible d’enregistrer le thème : $error');
    }
  }

  void _openProductGuide() {
    Navigator.of(_appContext!).push<void>(
      MaterialPageRoute<void>(builder: (_) => const _ProductGuideScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Planify',
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
      theme: _theme,
      home: Builder(
        builder: (context) {
          _appContext = context;
          return _buildHome();
        },
      ),
    );
  }

  Widget _buildHome() {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        body: Center(
          child: _LoadErrorView(
            error: _loadError!,
            onRetry: _loadInitialData,
          ),
        ),
      );
    }
    final pages = [
      _todayPage(),
      _inboxPage(),
      _calendarPage(),
      _settingsPage(),
    ];
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _tabIndex, children: pages),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showTaskEditor,
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today_rounded),
            label: 'Aujourd’hui',
          ),
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox_rounded),
            label: 'Inbox',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Calendrier',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune_rounded),
            label: 'Réglages',
          ),
        ],
      ),
    );
  }

  Future<void> _showTaskEditor({PlanoTask? task}) async {
    final result = await showModalBottomSheet<_TaskFormResult>(
      context: _appContext!,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TaskEditorSheet(task: task),
    );
    if (result == null) return;
    if (result.deleteId != null) {
      setState(() => _tasks.removeWhere((item) => item.id == result.deleteId));
      if (!await _persistTasks()) return;
      return;
    }
    final updated = result.task!;
    setState(() {
      final index = _tasks.indexWhere((item) => item.id == updated.id);
      if (index < 0) {
        _tasks.add(updated);
      } else {
        _tasks[index] = updated;
      }
    });
    if (!await _persistTasks()) return;
    _showMessage(
      task == null ? 'Tâche ajoutée à l’Inbox' : 'Tâche mise à jour',
    );
  }

  Future<void> _captureTask(String title) async {
    if (title.trim().isEmpty) return;
    setState(() {
      _tasks.add(
        PlanoTask(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: title.trim(),
        ),
      );
    });
    await _persistTasks();
  }

  Future<void> _openPlannerSetup({PlanoTask? onlyTask}) async {
    final selectedTasks = <PlanoTask>[];
    if (onlyTask == null) {
      selectedTasks.addAll(
        _tasks.where(
          (task) =>
              task.status == TaskStatus.inbox ||
              (task.status == TaskStatus.scheduled &&
                  task.scheduledStart != null &&
                  _sameDay(task.scheduledStart!, _selectedDate)),
        ),
      );
    } else {
      if (onlyTask.isLocked) {
        _showMessage('Cette tâche est verrouillée à son horaire actuel');
        return;
      }
      selectedTasks.add(onlyTask);
      selectedTasks.addAll(
        _tasks.where(
          (task) =>
              task.isLocked &&
              task.status == TaskStatus.scheduled &&
              task.scheduledStart != null &&
              _sameDay(task.scheduledStart!, _selectedDate) &&
              task.id != onlyTask.id,
        ),
      );
    }
    if (selectedTasks.isEmpty) {
      _showMessage('Aucune tâche à planifier dans l’Inbox');
      return;
    }
    final settings = await showModalBottomSheet<_PlannerOptions>(
      context: _appContext!,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PlannerSetupSheet(
        taskCount: selectedTasks.length,
        totalMinutes: selectedTasks.fold<int>(
          0,
          (sum, task) => sum + (task.durationMinutes ?? 30),
        ),
        fixedCount: _events.length,
        workWindow:
            '${_timeOfDayLabel(_workStart)} – ${_timeOfDayLabel(_workEnd)}',
      ),
    );
    if (settings == null || !mounted) return;
    final date = _dateOnly(_selectedDate);
    final plannerSettings = PlanSettings(
      workStart: _atTime(date, _workStart.hour, _workStart.minute),
      workEnd: _atTime(date, _workEnd.hour, _workEnd.minute),
      lunchStart: settings.respectLunch ? _atTime(date, 12, 30) : null,
      lunchEnd: settings.respectLunch ? _atTime(date, 13, 30) : null,
      bufferMinutes: settings.addBuffer ? 10 : 0,
      difficultTasksInMorning: settings.difficultMorning,
    );
    final result = generatePlan(
      tasks: selectedTasks,
      fixedEvents: _events,
      settings: plannerSettings,
    );
    final approval = await Navigator.of(_appContext!).push<_PlanApproval>(
      MaterialPageRoute(
        builder: (context) => _PlanPreviewPage(
          result: result,
          selectedDate: _selectedDate,
          events: _events,
        ),
      ),
    );
    if (approval != null && mounted) {
      await _applyPlan(result, approval.lockedTaskIds);
    }
  }

  Future<void> _applyPlan(
    PlanResult result,
    Set<String> lockedTaskIds,
  ) async {
    _lastSnapshot = List<PlanoTask>.of(_tasks);
    setState(() {
      for (final placement in result.placements) {
        final index = _tasks.indexWhere((task) => task.id == placement.task.id);
        if (index < 0) continue;
        _tasks[index] = _tasks[index].copyWith(
          status: TaskStatus.scheduled,
          scheduledStart: placement.start,
          scheduledEnd: placement.end,
          isAiProposed: false,
          durationMinutes: placement.task.durationMinutes ?? 30,
          isDurationEstimated: placement.task.durationMinutes == null,
          isLocked: lockedTaskIds.contains(placement.task.id),
        );
      }
      for (final task in result.unplaced) {
        final index = _tasks.indexWhere((item) => item.id == task.id);
        if (index < 0) continue;
        _tasks[index] = _tasks[index].copyWith(
          status: TaskStatus.inbox,
          clearSchedule: true,
        );
      }
    });
    if (!await _persistTasks()) return;
    ScaffoldMessenger.of(_appContext!).showSnackBar(
      SnackBar(
        content: const Text('Planning modifié'),
        action: SnackBarAction(label: 'Annuler', onPressed: _undoLastPlan),
      ),
    );
    setState(() => _tabIndex = 0);
  }

  Future<void> _undoLastPlan() async {
    final snapshot = _lastSnapshot;
    if (snapshot == null) return;
    setState(() {
      _tasks
        ..clear()
        ..addAll(snapshot);
      _lastSnapshot = null;
    });
    if (!await _persistTasks()) return;
    _showMessage('Le planning précédent a été restauré');
  }

  Future<void> _deleteTask(PlanoTask task) async {
    setState(() => _tasks.removeWhere((item) => item.id == task.id));
    if (!await _persistTasks()) return;
    _showMessage('Tâche supprimée');
  }

  Future<void> _toggleTaskLock(PlanoTask task) async {
    setState(() {
      final index = _tasks.indexWhere((item) => item.id == task.id);
      if (index >= 0) {
        _tasks[index] = _tasks[index].copyWith(
          isLocked: !_tasks[index].isLocked,
        );
      }
    });
    if (!await _persistTasks()) return;
    _showMessage(task.isLocked ? 'Horaire déverrouillé' : 'Horaire verrouillé');
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: _appContext!,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
    );
    if (selected != null) {
      await _selectDate(selected);
    }
  }

  Future<void> _editWorkHours() async {
    final start = await showTimePicker(
      context: _appContext!,
      initialTime: _workStart,
      helpText: 'Début de journée',
    );
    if (!mounted || start == null) return;
    final end = await showTimePicker(
      context: _appContext!,
      initialTime: _workEnd,
      helpText: 'Fin de journée',
    );
    if (!mounted || end == null) return;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    if (endMinutes <= startMinutes) {
      _showMessage('La fin de journée doit être après son début');
      return;
    }
  final schedule = WorkSchedule(
    startMinute: startMinutes,
    endMinute: endMinutes,
  );
  try {
    await _repository.saveWorkSchedule(schedule);
    if (!mounted) return;
    setState(() {
      _workStart = start;
      _workEnd = end;
    });
  } on Object catch (error) {
    _showMessage('Impossible d’enregistrer les horaires : $error');
  }
  }

  Future<bool> _persistTasks() async {
    try {
      await _repository.saveTasks(List.unmodifiable(_tasks));
      return true;
    } on Object catch (error) {
      if (mounted) {
        _showMessage('Impossible d’enregistrer les tâches : $error');
      }
      return false;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(_appContext!)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
        child: Column(
          children: [
            Icon(icon, size: 34, color: _primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
