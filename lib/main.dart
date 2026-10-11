import 'dart:async';

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
  late final Timer _clockRefreshTimer;

  @override
  void initState() {
    super.initState();
    _clockRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    _loadInitialData();
  }

  @override
  void dispose() {
    _clockRefreshTimer.cancel();
    super.dispose();
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
        _repository.loadDarkMode(),
      ]);
      if (!mounted) return;
      setState(() {
        _tasks
          ..clear()
          ..addAll(values[0] as List<PlanoTask>);
        _events = values[1] as List<FixedEvent>;
        _darkMode = values[2] as bool;
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadError != null) {
      return Scaffold(
        body: Center(
          child: _LoadErrorView(error: _loadError!, onRetry: _loadInitialData),
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
    if (task != null && _isTaskPast(task)) {
      _showMessage(
        'Cette tâche passée ne peut plus être modifiée ou supprimée',
      );
      return;
    }
    final result = await showModalBottomSheet<_TaskFormResult>(
      context: _appContext!,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _TaskEditorSheet(task: task, initialScheduleDate: _selectedDate),
    );
    if (result == null) return;
    if (task != null && _isTaskPast(task)) {
      _showMessage(
        'Cette tâche passée ne peut plus être modifiée ou supprimée',
      );
      return;
    }
    if (result.deleteId != null) {
      final taskToDelete = _tasks.where((item) => item.id == result.deleteId);
      if (taskToDelete.isNotEmpty && _isTaskPast(taskToDelete.first)) {
        _showMessage('Cette tâche passée ne peut plus être supprimée');
        return;
      }
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
    if (hasScheduleOverlap(updated, _tasks)) {
      _showMessage(
        'Chevauchement détecté : les tâches concernées sont signalées en rouge',
      );
      return;
    }
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
                  !_isTaskPast(task) &&
                  task.scheduledStart != null &&
                  _sameDay(task.scheduledStart!, _selectedDate)),
        ),
      );
    } else {
      if (_isTaskPast(onlyTask)) {
        _showMessage('Cette tâche passée ne peut plus être réorganisée');
        return;
      }
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
              !_isTaskPast(task) &&
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
    final date = _dateOnly(_selectedDate);
    while (mounted) {
      final options = await showModalBottomSheet<_PlannerOptions>(
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
        ),
      );
      if (options == null || !mounted) return;
      final result = generatePlan(
        tasks: selectedTasks,
        fixedEvents: _events,
        settings: PlanSettings(
          dayStart: date,
          dayEnd: _atTime(date, 24, 0),
          lunchStart: options.respectLunch ? _atTime(date, 12, 30) : null,
          lunchEnd: options.respectLunch ? _atTime(date, 13, 30) : null,
          bufferMinutes: options.addBuffer ? 10 : 0,
          prioritizeHighPriority: options.prioritizeHighPriority,
        ),
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
      if (approval == null || !mounted) return;
      if (approval.editOptions) continue;
      await _applyPlan(result, approval.lockedTaskIds);
      return;
    }
  }

  Future<void> _applyPlan(PlanResult result, Set<String> lockedTaskIds) async {
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
        duration: const Duration(seconds: 2),
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
    if (_isTaskPast(task)) {
      _showMessage('Cette tâche passée ne peut plus être supprimée');
      return;
    }
    setState(() => _tasks.removeWhere((item) => item.id == task.id));
    if (!await _persistTasks()) return;
    _showMessage('Tâche supprimée');
  }

  Future<void> _toggleTaskLock(PlanoTask task) async {
    if (_isTaskPast(task)) {
      _showMessage('Cette tâche passée ne peut plus être modifiée');
      return;
    }
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
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  bool _isTaskPast(PlanoTask task) => isTaskPast(task, DateTime.now());

  bool _hasScheduleConflict(PlanoTask task) => hasScheduleOverlap(task, _tasks);

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
