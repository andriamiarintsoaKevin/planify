import 'dart:math' as math;

enum TaskPriority { low, medium, high }

enum TaskStatus { inbox, scheduled, inProgress, done, postponed }

class PlanoTask {
  const PlanoTask({
    required this.id,
    required this.title,
    this.notes = '',
    this.durationMinutes,
    this.priority = TaskPriority.medium,
    this.dueDate,
    this.plannedEnd,
    this.status = TaskStatus.inbox,
    this.scheduledStart,
    this.project = '',
    this.isLocked = false,
    this.isAiProposed = false,
    this.isDurationEstimated = false,
    this.reminderEnabled = false,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String title;
  final String notes;
  final int? durationMinutes;
  final TaskPriority priority;
  final DateTime? dueDate;
  final DateTime? plannedEnd;
  final TaskStatus status;
  final DateTime? scheduledStart;
  final String project;
  final bool isLocked;
  final bool isAiProposed;
  final bool isDurationEstimated;
  final bool reminderEnabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  PlanoTask copyWith({
    String? title,
    String? notes,
    int? durationMinutes,
    TaskPriority? priority,
    DateTime? dueDate,
    DateTime? plannedEnd,
    TaskStatus? status,
    DateTime? scheduledStart,
    String? project,
    bool? isLocked,
    bool? isAiProposed,
    bool? isDurationEstimated,
    bool? reminderEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDueDate = false,
    bool clearSchedule = false,
  }) {
    return PlanoTask(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      priority: priority ?? this.priority,
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
      plannedEnd: clearSchedule ? null : plannedEnd ?? this.plannedEnd,
      status: status ?? this.status,
      scheduledStart: clearSchedule
          ? null
          : scheduledStart ?? this.scheduledStart,
      project: project ?? this.project,
      isLocked: isLocked ?? this.isLocked,
      isAiProposed: isAiProposed ?? this.isAiProposed,
      isDurationEstimated: isDurationEstimated ?? this.isDurationEstimated,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}

class FixedEvent {
  const FixedEvent({
    required this.title,
    required this.start,
    required this.end,
  });

  final String title;
  final DateTime start;
  final DateTime end;
}

class TaskPlacement {
  const TaskPlacement({
    required this.task,
    required this.start,
    required this.end,
  });

  final PlanoTask task;
  final DateTime start;
  final DateTime end;
}

class PlanResult {
  const PlanResult({
    required this.placements,
    required this.unplaced,
    required this.explanations,
  });

  final List<TaskPlacement> placements;
  final List<PlanoTask> unplaced;
  final List<String> explanations;
}

class PlanSettings {
  const PlanSettings({
    required this.dayStart,
    required this.dayEnd,
    this.lunchStart,
    this.lunchEnd,
    this.bufferMinutes = 0,
    this.prioritizeHighPriority = false,
  });

  final DateTime dayStart;
  final DateTime dayEnd;
  final DateTime? lunchStart;
  final DateTime? lunchEnd;
  final int bufferMinutes;
  final bool prioritizeHighPriority;
}

DateTime? plannedEndForTask({
  required DateTime? start,
  required int? durationMinutes,
}) {
  if (start == null) return null;
  return start.add(Duration(minutes: durationMinutes ?? 30));
}

PlanResult generatePlan({
  required List<PlanoTask> tasks,
  required List<FixedEvent> fixedEvents,
  required PlanSettings settings,
}) {
  final fixed = <_Interval>[
    for (final event in fixedEvents)
      if (event.end.isAfter(settings.dayStart) &&
          event.start.isBefore(settings.dayEnd))
        _Interval(
          event.start.isBefore(settings.dayStart)
              ? settings.dayStart
              : event.start,
          event.end.isAfter(settings.dayEnd) ? settings.dayEnd : event.end,
        ),
    if (settings.lunchStart != null &&
        settings.lunchEnd != null &&
        settings.lunchEnd!.isAfter(settings.dayStart) &&
        settings.lunchStart!.isBefore(settings.dayEnd))
      _Interval(
        settings.lunchStart!.isBefore(settings.dayStart)
            ? settings.dayStart
            : settings.lunchStart!,
        settings.lunchEnd!.isAfter(settings.dayEnd)
            ? settings.dayEnd
            : settings.lunchEnd!,
      ),
    for (final task in tasks)
      if (task.isLocked &&
          task.scheduledStart != null &&
          task.plannedEnd != null)
        _Interval(task.scheduledStart!, task.plannedEnd!),
  ]..sort((a, b) => a.start.compareTo(b.start));

  final orderedTasks =
      tasks
          .where(
            (task) =>
                !task.isLocked ||
                task.scheduledStart == null ||
                task.plannedEnd == null,
          )
          .toList()
        ..sort((a, b) {
          final aDueDate = a.dueDate ?? DateTime(9999);
          final bDueDate = b.dueDate ?? DateTime(9999);
          final dueDateOrder = aDueDate.compareTo(bDueDate);
          if (dueDateOrder != 0) return dueDateOrder;
          if (settings.prioritizeHighPriority) {
            final priorityOrder = b.priority.index.compareTo(a.priority.index);
            if (priorityOrder != 0) return priorityOrder;
          }
          return (b.durationMinutes ?? 30).compareTo(a.durationMinutes ?? 30);
        });

  final occupied = List<_Interval>.of(fixed);
  final placements = <TaskPlacement>[];
  final unplaced = <PlanoTask>[];

  for (final task in orderedTasks) {
    final duration = task.durationMinutes ?? 30;
    final possibleIntervals = _freeIntervals(
      occupied,
      settings.dayStart,
      settings.dayEnd,
      settings.bufferMinutes,
    );
    var placementFound = false;
    for (final slot in possibleIntervals) {
      final candidateStart = slot.start;
      final candidateEnd = candidateStart.add(Duration(minutes: duration));
      if (candidateEnd.isAfter(slot.end)) continue;
      if (task.dueDate != null && candidateEnd.isAfter(task.dueDate!)) {
        continue;
      }
      final placement = TaskPlacement(
        task: task,
        start: candidateStart,
        end: candidateEnd,
      );
      placements.add(placement);
      occupied.add(_Interval(candidateStart, candidateEnd));
      occupied.sort((a, b) => a.start.compareTo(b.start));
      placementFound = true;
      break;
    }

    if (!placementFound) unplaced.add(task);
  }

  placements.sort((a, b) => a.start.compareTo(b.start));
  return PlanResult(
    placements: placements,
    unplaced: unplaced,
    explanations: _makeExplanations(
      placements,
      prioritizeHighPriority: settings.prioritizeHighPriority,
    ),
  );
}

List<_Interval> _freeIntervals(
  List<_Interval> occupied,
  DateTime start,
  DateTime end,
  int bufferMinutes,
) {
  var cursor = start;
  final free = <_Interval>[];
  for (final interval in occupied) {
    if (!interval.end.isAfter(cursor)) continue;
    if (interval.start.isAfter(cursor)) {
      free.add(
        _Interval(cursor, interval.start.isBefore(end) ? interval.start : end),
      );
    }
    final bufferedEnd = interval.end.add(Duration(minutes: bufferMinutes));
    if (bufferedEnd.isAfter(cursor)) cursor = bufferedEnd;
    if (!cursor.isBefore(end)) break;
  }
  if (cursor.isBefore(end)) free.add(_Interval(cursor, end));
  return free;
}

List<String> _makeExplanations(
  List<TaskPlacement> placements, {
  required bool prioritizeHighPriority,
}) {
  if (placements.isEmpty) return [];
  final explanations = <String>[];
  for (final placement in placements) {
    final dueDate = placement.task.dueDate;
    if (dueDate != null && dueDate.difference(placement.end).inMinutes >= 0) {
      explanations.add(
        '${placement.task.title} est planifiée avant sa deadline de ${_formatTime(dueDate)}.',
      );
    }
    if (prioritizeHighPriority &&
        placement.task.priority == TaskPriority.high) {
      explanations.add(
        '${placement.task.title} a été favorisée en raison de sa priorité.',
      );
    }
  }
  if (placements.isNotEmpty && explanations.length < 3) {
    explanations.add(
      '${placements.length} tâche${placements.length > 1 ? 's' : ''} placée${placements.length > 1 ? 's' : ''} sans chevaucher les événements fixes.',
    );
  }
  const fallbackExplanations = [
    'Chaque tâche utilise un créneau disponible suffisamment long.',
    'Les dates limites ont été prises en compte pour ordonner les tâches.',
    'Aucune tâche proposée ne dépasse sa deadline.',
  ];
  for (final explanation in fallbackExplanations) {
    if (explanations.length == 3) break;
    explanations.add(explanation);
  }
  return explanations.take(3).toList();
}

bool hasScheduleOverlap(PlanoTask task, Iterable<PlanoTask> otherTasks) {
  final start = task.scheduledStart;
  final end = task.plannedEnd;
  if (task.status != TaskStatus.scheduled || start == null || end == null) {
    return false;
  }
  return otherTasks.any((other) {
    if (other.id == task.id || other.status != TaskStatus.scheduled) {
      return false;
    }
    final otherStart = other.scheduledStart;
    final otherEnd = other.plannedEnd;
    return otherStart != null &&
        otherEnd != null &&
        start.isBefore(otherEnd) &&
        otherStart.isBefore(end);
  });
}

bool isTaskPast(PlanoTask task, DateTime now) =>
    task.status == TaskStatus.scheduled &&
    task.plannedEnd != null &&
    !task.plannedEnd!.isAfter(now);

bool taskOverlapsDay(PlanoTask task, DateTime day) {
  final start = task.scheduledStart;
  final end = task.plannedEnd;
  if (task.status != TaskStatus.scheduled || start == null || end == null) {
    return false;
  }
  final dayStart = DateTime(day.year, day.month, day.day);
  final dayEnd = DateTime(day.year, day.month, day.day + 1);
  return start.isBefore(dayEnd) && end.isAfter(dayStart);
}

DateTime taskVisibleStartOnDay(PlanoTask task, DateTime day) {
  final start = task.scheduledStart!;
  final dayStart = DateTime(day.year, day.month, day.day);
  return start.isBefore(dayStart) ? dayStart : start;
}

DateTime taskVisibleEndOnDay(PlanoTask task, DateTime day) {
  final end = task.plannedEnd!;
  final dayEnd = DateTime(day.year, day.month, day.day + 1);
  return end.isAfter(dayEnd) ? dayEnd : end;
}

int taskDurationOnDay(PlanoTask task, DateTime day) {
  if (!taskOverlapsDay(task, day)) return 0;
  return taskVisibleEndOnDay(
    task,
    day,
  ).difference(taskVisibleStartOnDay(task, day)).inMinutes;
}

String _formatTime(DateTime dateTime) =>
    '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

double taskTopOffset(DateTime start, DateTime dayStart) {
  return (start.difference(dayStart).inMinutes / 60) * 72;
}

double taskHeight(int durationMinutes) {
  return math.max((durationMinutes / 60) * 72, 28);
}

class _Interval {
  const _Interval(this.start, this.end);

  final DateTime start;
  final DateTime end;
}
