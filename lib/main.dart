import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'planner.dart';

part 'today_screen.dart';
part 'inbox_screen.dart';
part 'calendar_screen.dart';
part 'settings_screen.dart';
part 'app_theme.dart';
part 'task_editor.dart';
part 'planner_sheets.dart';
part 'ui_helpers.dart';

void main() {
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
const _projectColors = <String, Color>{
  'Studio': Color(0xFF3B82F6),
  'Client A': Color(0xFFEC4899),
  'Personnel': Color(0xFF22C55E),
  'Projet': Color(0xFF8B5CF6),
  'Marketing': Color(0xFFF97316),
};

class PlanoApp extends StatefulWidget {
  const PlanoApp({super.key});

  @override
  State<PlanoApp> createState() => _PlanoAppState();
}

class _PlanoAppState extends State<PlanoApp> {
  bool _darkMode = false;
  TimeOfDay _workStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _workEnd = const TimeOfDay(hour: 18, minute: 0);
  final _tasks = <PlanoTask>[];
  DateTime _selectedDate = _dateOnly(DateTime.now());
  List<FixedEvent> _events = [];
  int _tabIndex = 0;
  List<PlanoTask>? _lastSnapshot;
  BuildContext? _appContext;

  @override
  void initState() {
    super.initState();
    _tasks.addAll([
      PlanoTask(
        id: 'task-1',
        title: 'Préparer la proposition commerciale',
        project: 'Client A',
        durationMinutes: 60,
        priority: TaskPriority.high,
        deadline: _atTime(_selectedDate, 17, 0),
      ),
      PlanoTask(
        id: 'task-2',
        title: 'Répondre aux retours du site',
        project: 'Studio',
        durationMinutes: 45,
        priority: TaskPriority.medium,
      ),
      PlanoTask(
        id: 'task-3',
        title: 'Envoyer la facture de septembre',
        project: 'Personnel',
        durationMinutes: 30,
        priority: TaskPriority.low,
      ),
      PlanoTask(
        id: 'task-4',
        title: 'Revoir le brief du projet',
        project: 'Projet',
        durationMinutes: 90,
        priority: TaskPriority.high,
        deadline: _atTime(_selectedDate, 18, 0),
      ),
    ]);
    _updateEvents();
  }

  void _updateEvents() {
    _events = [
      FixedEvent(
        title: 'Point client',
        start: _atTime(_selectedDate, 11, 0),
        end: _atTime(_selectedDate, 11, 45),
      ),
    ];
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = _dateOnly(date);
      _updateEvents();
    });
  }

  void _setDarkMode(bool enabled) {
    setState(() => _darkMode = enabled);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Plano',
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
    _showMessage(
      task == null ? 'Tâche ajoutée à l’Inbox' : 'Tâche mise à jour',
    );
  }

  void _captureTask(String title) {
    if (title.trim().isEmpty) return;
    setState(() {
      _tasks.add(
        PlanoTask(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: title.trim(),
        ),
      );
    });
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
      _applyPlan(result, approval.lockedTaskIds);
    }
  }

  void _applyPlan(PlanResult result, Set<String> lockedTaskIds) {
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
    ScaffoldMessenger.of(_appContext!).showSnackBar(
      SnackBar(
        content: const Text('Planning modifié'),
        action: SnackBarAction(label: 'Annuler', onPressed: _undoLastPlan),
      ),
    );
    setState(() => _tabIndex = 0);
  }

  void _undoLastPlan() {
    final snapshot = _lastSnapshot;
    if (snapshot == null) return;
    setState(() {
      _tasks
        ..clear()
        ..addAll(snapshot);
      _lastSnapshot = null;
    });
    _showMessage('Le planning précédent a été restauré');
  }

  void _deleteTask(PlanoTask task) {
    setState(() => _tasks.removeWhere((item) => item.id == task.id));
    _showMessage('Tâche supprimée');
  }

  void _toggleTaskLock(PlanoTask task) {
    setState(() {
      final index = _tasks.indexWhere((item) => item.id == task.id);
      if (index >= 0) {
        _tasks[index] = _tasks[index].copyWith(
          isLocked: !_tasks[index].isLocked,
        );
      }
    });
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
      setState(() {
        _selectedDate = _dateOnly(selected);
        _updateEvents();
      });
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
    setState(() {
      _workStart = start;
      _workEnd = end;
    });
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
