part of '../../main.dart';

extension _PlanoTodayScreen on _PlanoAppState {
  Widget _todayPage() {
    final scheduled =
        _tasks
            .where(
              (task) =>
                  task.status == TaskStatus.scheduled &&
                  taskOverlapsDay(task, _selectedDate),
            )
            .toList()
          ..sort(
            (a, b) => taskVisibleStartOnDay(
              a,
              _selectedDate,
            ).compareTo(taskVisibleStartOnDay(b, _selectedDate)),
          );
    final totalMinutes = scheduled.fold<int>(
      0,
      (sum, task) => sum + taskDurationOnDay(task, _selectedDate),
    );
    final load = (totalMinutes / (24 * 60)).clamp(0.0, 1.0);
    final dateLabel = _selectedDate == _dateOnly(DateTime.now())
        ? 'AUJOURD’HUI'
        : _formatDate(_selectedDate).toUpperCase();
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
          sliver: SliverList.list(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateLabel,
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Aujourd’hui',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Choisir une date',
                    onPressed: _chooseDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _dayStrip(),
              const SizedBox(height: 18),
              _summaryCard(scheduled.length, totalMinutes, load),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _openPlannerSetup,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Réorganiser ma journée'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  minimumSize: const Size.fromHeight(50),
                  side: const BorderSide(color: _primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Votre planning',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${scheduled.length} tâches',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (scheduled.isEmpty)
                _emptyCard(
                  icon: Icons.event_available_outlined,
                  title: 'Tout est planifié',
                  message: 'Votre journée est libre. Ajoutez une tâche ou planifiez celles de votre Inbox.',
                )
              else
                _timeline(scheduled),
              if (_events.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'Événements fixes · ${_events.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                for (final event in _events) _eventTile(event),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _dayStrip() {
    final firstDay = _selectedDate.subtract(
      Duration(days: (_selectedDate.weekday - DateTime.monday) % 7),
    );
    return Row(
      children: List.generate(7, (index) {
        final date = firstDay.add(Duration(days: index));
        final isSelected = _sameDay(date, _selectedDate);
        final hasTasks = _tasks.any(
          (task) =>
              task.status != TaskStatus.done && taskOverlapsDay(task, date),
        );
        return Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _selectDate(date),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Text(
                    const ['L', 'M', 'M', 'J', 'V', 'S', 'D'][index],
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? _primary : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: const Color.fromARGB(255, 104, 129, 150),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: hasTasks ? _primary : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _summaryCard(int taskCount, int totalMinutes, double load) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            SizedBox(
              width: 66,
              height: 66,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: load,
                    strokeWidth: 7,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    color: load >= 1 ? _warning : _primary,
                  ),
                  Text(
                    '${(load * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$taskCount tâches · ${hours}h ${minutes}min planifiées',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    load >= 1
                        ? 'Votre journée est bien remplie'
                        : 'Tout rentre dans votre journée',
                    style: TextStyle(
                      color: load >= 1 ? _warning : _success,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeline(List<PlanoTask> scheduled) {
    const dayStartHour = 0;
    const hourHeight = 72.0;
    final dayStart = _atTime(_selectedDate, dayStartHour, 0);
    final overlappingTasks = scheduled.where(_hasScheduleConflict).toList();
    final overlapLaneByTaskId = <String, int>{};
    var overlapLaneCount = 1;
    for (final task in overlappingTasks) {
      var lane = 0;
      while (overlappingTasks.any(
        (other) =>
            overlapLaneByTaskId[other.id] == lane &&
            hasScheduleOverlap(task, [other]),
      )) {
        lane++;
      }
      overlapLaneByTaskId[task.id] = lane;
      if (lane >= overlapLaneCount) overlapLaneCount = lane + 1;
    }
    final visibleEvents = _events.where(
      (event) =>
          _sameDay(event.start, _selectedDate) &&
          event.end.isAfter(dayStart) &&
          event.start.isBefore(_atTime(_selectedDate, 24, 0)),
    );
    return DragTarget<PlanoTask>(
      onWillAcceptWithDetails: (details) => !details.data.isLocked,
      onAcceptWithDetails: _handleTimelineDrop,
      builder: (context, candidates, rejected) => Card(
        key: _timelineKey,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 24 * hourHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final timelineWidth = constraints.maxWidth - 56;
              return Stack(
                children: [
                  for (var hour = 0; hour <= 24; hour++)
                    Positioned(
                      top: hour * hourHeight,
                      left: 8,
                      right: 8,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 42,
                            child: Text(
                              '${(dayStartHour + hour).toString().padLeft(2, '0')}:00',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (final event in visibleEvents)
                    _positionedTimelineBlock(
                      start: event.start,
                      duration: event.end.difference(event.start).inMinutes,
                      dayStart: dayStart,
                      left: 54,
                      width: timelineWidth,
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_outlined,
                            size: 15,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${event.title} · ${_clock(event.start)}–${_clock(event.end)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (final task in scheduled)
                    if (task.scheduledStart != null &&
                        task.scheduledEnd != null &&
                        taskOverlapsDay(task, _selectedDate))
                      _positionedTimelineBlock(
                        start: taskVisibleStartOnDay(task, _selectedDate),
                        duration: taskDurationOnDay(task, _selectedDate),
                        dayStart: dayStart,
                        left:
                            54 +
                            (overlapLaneByTaskId.containsKey(task.id)
                                ? overlapLaneByTaskId[task.id]! *
                                      timelineWidth /
                                      overlapLaneCount
                                : 0),
                        width: overlapLaneByTaskId.containsKey(task.id)
                            ? timelineWidth / overlapLaneCount
                            : timelineWidth,
                        color: _priorityColor(context, task.priority),
                        isTaskBubble: true,
                        child: Opacity(
                          opacity: _isTaskPast(task) ? 0.45 : 1,
                          child: LongPressDraggable<PlanoTask>(
                            data: task,
                            maxSimultaneousDrags:
                                task.isLocked || _isTaskPast(task) ? 0 : 1,
                            feedback: Material(
                              color: Colors.transparent,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _priorityColor(context, task.priority),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  task.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            childWhenDragging: const SizedBox.shrink(),
                            child: InkWell(
                              onTap: () => _showTaskDetails(task),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 1,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        if (task.scheduledStart!.isBefore(
                                          taskVisibleStartOnDay(
                                            task,
                                            _selectedDate,
                                          ),
                                        ))
                                          Padding(
                                            padding: EdgeInsets.only(right: 4),
                                            child: Icon(
                                              Icons.subdirectory_arrow_right,
                                              size: 13,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                        Expanded(
                                          child: Text(
                                            task.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color.fromARGB(
                                                255,
                                                47,
                                                43,
                                                43,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (task.isLocked)
                                          Padding(
                                            padding: EdgeInsets.only(left: 4),
                                            child: Icon(
                                              Icons.lock_outline,
                                              size: 13,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                        if (_hasScheduleConflict(task))
                                          const Padding(
                                            padding: EdgeInsets.only(left: 3),
                                            child: Icon(
                                              Icons.warning_amber_rounded,
                                              size: 15,
                                              color: _danger,
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (taskDurationOnDay(
                                          task,
                                          _selectedDate,
                                        ) >=
                                        40)
                                      Text(
                                        _taskTimeRangeOnDay(
                                          task,
                                          _selectedDate,
                                        ),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Color.fromARGB(
                                            255,
                                            47,
                                            43,
                                            43,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  if (_sameDay(_selectedDate, DateTime.now()))
                    Positioned(
                      top:
                          (DateTime.now().hour * 60 +
                              DateTime.now().minute -
                              dayStartHour * 60) /
                          60 *
                          hourHeight,
                      left: 52,
                      right: 8,
                      child: const Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: _danger),
                          Expanded(child: Divider(color: _danger, height: 1)),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _positionedTimelineBlock({
    required DateTime start,
    required int duration,
    required DateTime dayStart,
    required double left,
    required double width,
    required Color color,
    required Widget child,
    bool isTaskBubble = false,
  }) {
    final top = taskTopOffset(start, dayStart);
    final height = taskHeight(duration);
    return Positioned(
      top: top,
      left: left,
      width: width,
      height: height,
      child: Container(
        margin: EdgeInsets.only(
          left: isTaskBubble ? 3 : 0,
          right: 4,
          top: isTaskBubble ? 2 : 0,
          bottom: 2,
        ),
        decoration: BoxDecoration(
          color: isTaskBubble
              ? Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.surfaceContainer
                    : Color.alphaBlend(
                        color.withValues(alpha: .1),
                        Theme.of(context).colorScheme.surface,
                      )
              : color,
          border: isTaskBubble
              ? Border.all(color: color.withValues(alpha: 0.75))
              : null,
          borderRadius: BorderRadius.circular(isTaskBubble ? 14 : 8),
          boxShadow: isTaskBubble
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: child,
      ),
    );
  }

  Widget _eventTile(FixedEvent event) => Card(
    child: ListTile(
      leading: Icon(
        Icons.event_available_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(event.title),
      subtitle: Text('${_clock(event.start)}–${_clock(event.end)} · Fixe'),
      dense: true,
    ),
  );
}
