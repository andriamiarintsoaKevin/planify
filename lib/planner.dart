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
    this.deadline,
    this.status = TaskStatus.inbox,
    this.scheduledStart,
    this.scheduledEnd,
    this.project = 'Personnel',
    this.isLocked = false,
    this.isAiProposed = false,
    this.isDurationEstimated = false,
  });

  final String id;
  final String title;
  final String notes;
  final int? durationMinutes;
  final TaskPriority priority;
  final DateTime? deadline;
  final TaskStatus status;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final String project;
  final bool isLocked;
  final bool isAiProposed;
  final bool isDurationEstimated;

  PlanoTask copyWith({
    String? title,
    String? notes,
    int? durationMinutes,
    TaskPriority? priority,
    DateTime? deadline,
    TaskStatus? status,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    String? project,
    bool? isLocked,
    bool? isAiProposed,
    bool? isDurationEstimated,
    bool clearDeadline = false,
    bool clearSchedule = false,
  }) {
    return PlanoTask(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      priority: priority ?? this.priority,
      deadline: clearDeadline ? null : deadline ?? this.deadline,
      status: status ?? this.status,
      scheduledStart: clearSchedule
          ? null
          : scheduledStart ?? this.scheduledStart,
      scheduledEnd: clearSchedule ? null : scheduledEnd ?? this.scheduledEnd,
      project: project ?? this.project,
      isLocked: isLocked ?? this.isLocked,
      isAiProposed: isAiProposed ?? this.isAiProposed,
      isDurationEstimated: isDurationEstimated ?? this.isDurationEstimated,
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
    required this.workStart,
    required this.workEnd,
    this.lunchStart,
    this.lunchEnd,
    this.bufferMinutes = 10,
    this.difficultTasksInMorning = true,
  });

  final DateTime workStart;
  final DateTime workEnd;
  final DateTime? lunchStart;
  final DateTime? lunchEnd;
  final int bufferMinutes;
  final bool difficultTasksInMorning;
}

PlanResult generatePlan({
  required List<PlanoTask> tasks,
  required List<FixedEvent> fixedEvents,
  required PlanSettings settings,
}) {
  final fixed = <_Interval>[
    for (final event in fixedEvents)
      if (event.end.isAfter(settings.workStart) &&
          event.start.isBefore(settings.workEnd))
        _Interval(
          event.start.isBefore(settings.workStart)
              ? settings.workStart
              : event.start,
          event.end.isAfter(settings.workEnd) ? settings.workEnd : event.end,
        ),
    if (settings.lunchStart != null &&
        settings.lunchEnd != null &&
        settings.lunchEnd!.isAfter(settings.workStart) &&
        settings.lunchStart!.isBefore(settings.workEnd))
      _Interval(
        settings.lunchStart!.isBefore(settings.workStart)
            ? settings.workStart
            : settings.lunchStart!,
        settings.lunchEnd!.isAfter(settings.workEnd)
            ? settings.workEnd
            : settings.lunchEnd!,
      ),
    for (final task in tasks)
      if (task.isLocked &&
          task.scheduledStart != null &&
          task.scheduledEnd != null)
        _Interval(task.scheduledStart!, task.scheduledEnd!),
  ]..sort((a, b) => a.start.compareTo(b.start));

  final orderedTasks =
      tasks
          .where(
            (task) =>
                !task.isLocked ||
                task.scheduledStart == null ||
                task.scheduledEnd == null,
          )
          .toList()
        ..sort((a, b) {
          final aDeadline = a.deadline ?? DateTime(9999);
          final bDeadline = b.deadline ?? DateTime(9999);
          final deadlineOrder = aDeadline.compareTo(bDeadline);
          if (deadlineOrder != 0) return deadlineOrder;
          final priorityOrder = b.priority.index.compareTo(a.priority.index);
          if (priorityOrder != 0) return priorityOrder;
          return (b.durationMinutes ?? 30).compareTo(a.durationMinutes ?? 30);
        });

  final occupied = List<_Interval>.of(fixed);
  final placements = <TaskPlacement>[];
  final unplaced = <PlanoTask>[];

  for (final task in orderedTasks) {
    final duration = task.durationMinutes ?? 30;
    final possibleIntervals = _freeIntervals(
      occupied,
      settings.workStart,
      settings.workEnd,
      settings.bufferMinutes,
    );
    var placementFound = false;
    final prefersMorning =
        settings.difficultTasksInMorning && task.priority == TaskPriority.high;
    final candidates = prefersMorning
        ? [
            ...possibleIntervals.where((slot) => slot.start.hour < 12),
            ...possibleIntervals.where((slot) => slot.start.hour >= 12),
          ]
        : possibleIntervals;

    for (final slot in candidates) {
      final candidateStart = slot.start;
      final candidateEnd = candidateStart.add(Duration(minutes: duration));
      if (candidateEnd.isAfter(slot.end)) continue;
      if (task.deadline != null && candidateEnd.isAfter(task.deadline!)) {
        continue;
      }
      final placement = TaskPlacement(
        task: task,
        start: candidateStart,
        end: candidateEnd,
      );
      placements.add(placement);
      occupied.add(
        _Interval(
          candidateStart,
          candidateEnd.add(Duration(minutes: settings.bufferMinutes)),
        ),
      );
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
    explanations: _makeExplanations(placements),
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
      free.add(_Interval(cursor, interval.start));
    }
    final bufferedEnd = interval.end.add(Duration(minutes: bufferMinutes));
    if (bufferedEnd.isAfter(cursor)) cursor = bufferedEnd;
    if (!cursor.isBefore(end)) break;
  }
  if (cursor.isBefore(end)) free.add(_Interval(cursor, end));
  return free;
}

List<String> _makeExplanations(List<TaskPlacement> placements) {
  if (placements.isEmpty) return [];
  final explanations = <String>[];
  for (final placement in placements) {
    final deadline = placement.task.deadline;
    if (deadline != null && deadline.difference(placement.end).inMinutes >= 0) {
      explanations.add(
        '${placement.task.title} est planifiée avant sa deadline de ${_formatTime(deadline)}.',
      );
    }
    if (placement.task.priority == TaskPriority.high &&
        placement.start.hour < 12) {
      explanations.add('${placement.task.title} est placée le matin.');
    }
  }
  if (placements.isNotEmpty && explanations.length < 3) {
    explanations.add(
      '${placements.length} tâche${placements.length > 1 ? 's' : ''} placée${placements.length > 1 ? 's' : ''} sans chevaucher les événements fixes.',
    );
  }
  const fallbackExplanations = [
    'Chaque tâche utilise un créneau disponible suffisamment long.',
    'Les deadlines ont été prises en compte pour ordonner les tâches.',
    'Aucune tâche proposée ne dépasse sa deadline.',
  ];
  for (final explanation in fallbackExplanations) {
    if (explanations.length == 3) break;
    explanations.add(explanation);
  }
  return explanations.take(3).toList();
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
