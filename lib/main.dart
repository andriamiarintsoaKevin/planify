import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/database_initializer.dart';
import 'data/device_calendar_service.dart';
import 'data/local_reminder_service.dart';
import 'data/plano_repository.dart';
import 'data/sqlite_planify_repository.dart';
import 'domain/planner.dart';

import 'package:device_calendar_plus/device_calendar_plus.dart' show Calendar;

part 'ui/screens/today_screen.dart';
part 'ui/screens/inbox_screen.dart';
part 'ui/screens/calendar_screen.dart';
part 'ui/screens/settings_screen.dart';
part 'ui/theme/app_theme.dart';
part 'ui/sheets/task_editor.dart';
part 'ui/sheets/task_details.dart';
part 'ui/sheets/planner_sheets.dart';
part 'ui/widgets/ui_helpers.dart';
part 'ui/screens/product_guide.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializePlanifyDatabase();
  await LocalReminderService().initialize();
  runApp(const PlanoApp());
}

const _primary = Color(0xFF4F46E5);
const _primarySoft = Color(0xFFEEF0FF);
const _success = Color(0xFF10B981);
const _warning = Color(0xFFF59E0B);
const _danger = Color(0xFFEF4444);
const _ink = Color(0xFF111827);
const _canvas = Color(0xFFF7F7FB);

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
  final _calendarService = DeviceCalendarService();
  final _reminderService = LocalReminderService();
  final _tasks = <PlanoTask>[];
  DateTime _selectedDate = _dateOnly(DateTime.now());
  List<FixedEvent> _events = [];
  String? _calendarId;
  final _timelineKey = GlobalKey();
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
      final values = await Future.wait<Object?>([
        _repository.loadTasks(),
        _repository.loadEvents(_selectedDate),
        _repository.loadDarkMode(),
        _repository.loadCalendarId(),
      ]);
      if (!mounted) return;
      setState(() {
        _tasks
          ..clear()
          ..addAll(values[0] as List<PlanoTask>);
        _events = values[1] as List<FixedEvent>;
        _darkMode = values[2] as bool;
        _calendarId = values[3] as String?;
        _isLoading = false;
      });
      if (_calendarId != null) {
        try {
          final calendarEvents = await _calendarService.loadEvents(
            _calendarId!,
            _selectedDate,
          );
          if (mounted) {
            setState(() => _events = [..._events, ...calendarEvents]);
          }
        } on Object catch (error) {
          if (mounted) {
            _showMessage('Calendrier non actualisé : $error');
          }
        }
      }
      try {
        await _syncAllReminders();
      } on Object catch (error) {
        if (mounted) _showMessage('Rappels non actualisés : $error');
      }
      if (defaultTargetPlatform == TargetPlatform.android &&
          _tasks.any(
            (task) =>
                task.reminderEnabled &&
                task.status == TaskStatus.scheduled &&
                task.scheduledStart?.isAfter(DateTime.now()) == true,
          ) &&
          await _reminderService.areNotificationsEnabled() == false &&
          mounted) {
        _showMessage(
          'Les notifications Android sont désactivées. Autorisez-les pour recevoir vos rappels.',
          actionLabel: 'Réglages',
          onAction: () async {
            await _reminderService.openNotificationSettings();
          },
        );
      }
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
      final events = <FixedEvent>[
        ...await _repository.loadEvents(selectedDate),
      ];
      final calendarId = _calendarId;
      if (calendarId != null) {
        events.addAll(
          await _calendarService.loadEvents(calendarId, selectedDate),
        );
      }
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
      builder: (context) => _TaskEditorSheet(
        task: task,
        initialScheduleDate: _selectedDate,
        remindersAvailable: _reminderService.isAvailable,
      ),
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
    String? reminderPermissionIssue;
    var notificationsDisabled = false;
    if (updated.reminderEnabled &&
        !(task?.reminderEnabled ?? false) &&
        _reminderService.isAvailable) {
      try {
        final permissionGranted = await _reminderService.requestPermission();
        if (!permissionGranted) {
          reminderPermissionIssue =
              'les notifications sont désactivées sur cet appareil';
          notificationsDisabled = true;
        } else if (updated.status == TaskStatus.scheduled &&
            updated.scheduledStart?.isAfter(DateTime.now()) == true &&
            defaultTargetPlatform == TargetPlatform.android &&
            !await _reminderService.requestExactAlarmPermission()) {
          reminderPermissionIssue =
              'l’alarme exacte est refusée : le rappel pourra être retardé par Android';
        }
      } on Object catch (error) {
        reminderPermissionIssue =
            'impossible de demander l’autorisation de notification : $error';
      }
    }
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
    final savedMessage = task == null
        ? 'Tâche ajoutée à l’Inbox'
        : 'Tâche mise à jour';
    _showMessage(
      reminderPermissionIssue == null
          ? savedMessage
          : '$savedMessage, mais $reminderPermissionIssue',
      actionLabel: notificationsDisabled ? 'Réglages' : null,
      onAction: notificationsDisabled
          ? () async {
              await _reminderService.openNotificationSettings();
            }
          : null,
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
    final date = _dateOnly(_selectedDate);
    final now = DateTime.now();
    final today = _dateOnly(now);
    if (date.isBefore(today)) {
      _showMessage('Impossible de planifier une tâche à une date passée');
      return;
    }
    final dayStart = _sameDay(date, today)
        ? DateTime(now.year, now.month, now.day, now.hour, now.minute).add(
            Duration(
              minutes:
                  now.second > 0 || now.millisecond > 0 || now.microsecond > 0
                  ? 1
                  : 0,
            ),
          )
        : date;
    if (!dayStart.isBefore(_atTime(date, 24, 0))) {
      _showMessage('Aucun horaire futur ne reste pour cette journée');
      return;
    }
    if (onlyTask == null) {
      selectedTasks.addAll(
        _tasks.where(
          (task) =>
              task.status == TaskStatus.inbox &&
              task.scheduledStart == null &&
              task.scheduledEnd == null,
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
      if (onlyTask.status != TaskStatus.inbox ||
          onlyTask.scheduledStart != null ||
          onlyTask.scheduledEnd != null) {
        _showMessage(
          'Seules les tâches sans horaire peuvent être réorganisées',
        );
        return;
      }
      selectedTasks.add(onlyTask);
    }
    if (selectedTasks.isEmpty) {
      _showMessage('Aucune tâche à planifier dans l’Inbox');
      return;
    }
    final planningEvents = [
      ..._events,
      for (final task in _tasks)
        if (task.status == TaskStatus.scheduled &&
            task.scheduledStart != null &&
            task.scheduledEnd != null &&
            task.scheduledEnd!.isAfter(date) &&
            task.scheduledStart!.isBefore(_atTime(date, 24, 0)))
          FixedEvent(
            title: task.title,
            start: task.scheduledStart!,
            end: task.scheduledEnd!,
          ),
    ];
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
          fixedCount: planningEvents.length,
        ),
      );
      if (options == null || !mounted) return;
      final result = generatePlan(
        tasks: selectedTasks,
        fixedEvents: planningEvents,
        settings: PlanSettings(
          dayStart: dayStart,
          dayEnd: _atTime(date, 24, 0),
          lunchStart: options.respectLunch ? _atTime(date, 12, 30) : null,
          lunchEnd: options.respectLunch
              ? _atTime(date, 12, 30).add(
                  Duration(minutes: options.lunchDurationMinutes),
                )
              : null,
          bufferMinutes: options.addBuffer ? 10 : 0,
          prioritizeHighPriority: options.prioritizeHighPriority,
        ),
      );
      final approval = await Navigator.of(_appContext!).push<_PlanApproval>(
        MaterialPageRoute(
          builder: (context) => _PlanPreviewPage(
            result: result,
            selectedDate: _selectedDate,
            events: planningEvents,
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
          deadline: placement.end,
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
          clearDeadline: true,
        );
      }
    });
    if (!await _persistTasks()) return;
    _showTopNotification(
      _appContext!,
      'Planning modifié',
      actionLabel: 'Annuler',
      onAction: _undoLastPlan,
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
    String? reminderIssue;
    try {
      await _reminderService.cancelTask(task);
    } on Object catch (error) {
      reminderIssue = 'rappel non annulé : $error';
    }
    _showMessage(
      reminderIssue == null
          ? 'Tâche supprimée'
          : 'Tâche supprimée, mais $reminderIssue',
    );
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
      try {
        await _syncAllReminders();
      } on Object catch (error) {
        if (mounted) {
          _showMessage(
            'Tâches enregistrées, mais rappels non actualisés : $error',
          );
        }
      }
      return true;
    } on Object catch (error) {
      if (mounted) {
        _showMessage('Impossible d’enregistrer les tâches : $error');
      }
      return false;
    }
  }

  Future<void> _syncAllReminders() async {
    if (!_reminderService.isAvailable) return;
    for (final task in _tasks) {
      await _reminderService.syncTask(task);
    }
  }

  Future<void> _connectCalendar() async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      _showMessage(
        'La connexion au calendrier est disponible sur Android et iPhone.',
      );
      return;
    }
    try {
      final calendars = await _calendarService.requestAccessAndLoadCalendars();
      if (!mounted) return;
      if (calendars.isEmpty) {
        _showMessage(
          'Aucun calendrier trouvé. Ajoutez un compte Google dans les réglages de votre appareil.',
        );
        return;
      }
      final selected = await showModalBottomSheet<Calendar>(
        context: _appContext!,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text('Choisir un calendrier'),
                subtitle: Text(
                  'Les événements seront consultés en lecture seule.',
                ),
              ),
              for (final calendar in calendars)
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: Text(calendar.name),
                    subtitle: Text(
                      [calendar.accountName, calendar.accountType]
                          .whereType<String>()
                          .where((value) => value.isNotEmpty)
                          .join(' · '),
                    ),
                    onTap: () => Navigator.pop(context, calendar),
                  ),
                ),
            ],
          ),
        ),
      );
      final selectedCalendarId = selected?.id;
      if (selectedCalendarId == null) return;
      await _repository.saveCalendarId(selectedCalendarId);
      if (!mounted) return;
      setState(() => _calendarId = selectedCalendarId);
      await _selectDate(_selectedDate);
      _showMessage('Calendrier connecté en lecture seule');
    } on Object catch (error) {
      _showMessage('Impossible de connecter le calendrier : $error');
    }
  }

  Future<void> _disconnectCalendar() async {
    try {
      await _repository.saveCalendarId(null);
      final localEvents = await _repository.loadEvents(_selectedDate);
      if (!mounted) return;
      setState(() {
        _calendarId = null;
        _events = localEvents;
      });
      _showMessage('Calendrier déconnecté');
    } on Object catch (error) {
      _showMessage('Impossible de déconnecter le calendrier : $error');
    }
  }

  Future<void> _showTaskDetails(PlanoTask task) async {
    await showModalBottomSheet<void>(
      context: _appContext!,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TaskDetailsSheet(
        task: task,
        canEdit: !_isTaskPast(task),
        onEdit: () {
          Navigator.pop(context);
          Future<void>.delayed(
            Duration.zero,
            () => _showTaskEditor(task: task),
          );
        },
      ),
    );
  }

  void _handleTimelineDrop(DragTargetDetails<PlanoTask> details) {
    final renderObject =
        _timelineKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderObject == null) return;
    final localOffset = renderObject.globalToLocal(details.offset);
    final minutes = ((localOffset.dy / 72 * 60) / 15).round() * 15;
    final start = _atTime(_selectedDate, 0, minutes);
    _moveTask(details.data, start);
  }

  Future<void> _moveTask(PlanoTask task, DateTime start) async {
    if (task.isLocked) {
      _showMessage('Déverrouillez cette tâche avant de la déplacer');
      return;
    }
    if (_isTaskPast(task) || start.isBefore(DateTime.now())) {
      _showMessage('Une tâche passée ne peut pas être déplacée');
      return;
    }
    final duration = task.durationMinutes ?? 30;
    final end = start.add(Duration(minutes: duration));
    if (end.isAfter(_atTime(_selectedDate, 24, 0))) {
      _showMessage('La tâche doit se terminer avant minuit');
      return;
    }
    setState(() {
      final index = _tasks.indexWhere((item) => item.id == task.id);
      if (index >= 0) {
        _tasks[index] = _tasks[index].copyWith(
          status: TaskStatus.scheduled,
          scheduledStart: start,
          scheduledEnd: end,
          deadline: end,
        );
      }
    });
    if (!await _persistTasks()) return;
    _showMessage(
      'Tâche déplacée · durée conservée à ${_durationLabel(duration)}',
    );
  }

  void _showMessage(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _showTopNotification(
      _appContext!,
      message,
      actionLabel: actionLabel,
      onAction: onAction,
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
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
