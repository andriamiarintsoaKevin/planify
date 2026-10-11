part of '../../main.dart';

extension _PlanoTodayScreen on _PlanoAppState {
  Widget _todayPage() {
    final scheduled =
        _tasks
            .where(
              (task) =>
                  task.status == TaskStatus.scheduled &&
                  task.scheduledStart != null &&
                  _sameDay(task.scheduledStart!, _selectedDate),
            )
            .toList()
          ..sort((a, b) => a.scheduledStart!.compareTo(b.scheduledStart!));
    final totalMinutes = scheduled.fold<int>(
      0,
      (sum, task) => sum + (task.durationMinutes ?? 0),
    );
    final load = (totalMinutes / (8 * 60)).clamp(0.0, 1.0);
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
                          style: const TextStyle(
                            fontSize: 12,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w600,
                            color: _muted,
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
                    style: const TextStyle(color: _muted),
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
              task.scheduledStart != null &&
              _sameDay(task.scheduledStart!, date) &&
              task.status != TaskStatus.done,
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
                    style: const TextStyle(color: _muted, fontSize: 12),
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
                        color: isSelected ? Colors.white : null,
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
                    backgroundColor: _primarySoft,
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
    const dayStartHour = 8;
    const hourHeight = 72.0;
    final dayStart = _atTime(_selectedDate, dayStartHour, 0);
    final visibleEvents = _events.where(
      (event) =>
          _sameDay(event.start, _selectedDate) &&
          event.end.isAfter(dayStart) &&
          event.start.hour < 19,
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 11 * hourHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final timelineWidth = constraints.maxWidth - 56;
            return Stack(
              children: [
                for (var hour = 0; hour <= 11; hour++)
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
                            style: const TextStyle(
                              fontSize: 11,
                              color: _muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: const Color(0xFFEDEEF2),
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
                    color: const Color(0xFFE5E7EB),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.event_outlined,
                          size: 15,
                          color: _muted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${event.title} · ${_clock(event.start)}–${_clock(event.end)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final task in scheduled)
                  if (task.scheduledStart != null &&
                      task.scheduledEnd != null &&
                      _sameDay(task.scheduledStart!, _selectedDate))
                    _positionedTimelineBlock(
                      start: task.scheduledStart!,
                      duration: (task.durationMinutes ?? 30),
                      dayStart: dayStart,
                      left: 54,
                      width: timelineWidth,
                      color: _projectColor(task.project)
                          .withValues(alpha: 0.13),
                      child: InkWell(
                        onTap: () => _showTaskEditor(task: task),
                        onLongPress: () => _toggleTaskLock(task),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              decoration: BoxDecoration(
                                color: _projectColor(task.project),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    task.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if ((task.durationMinutes ?? 30) >= 45)
                                    Text(
                                      '${_clock(task.scheduledStart!)}–${_clock(task.scheduledEnd!)}'
                                      '${task.project.isEmpty ? '' : ' · ${task.project}'}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: _muted,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (task.isLocked)
                              const Icon(
                                Icons.lock_outline,
                                size: 15,
                                color: _muted,
                              ),
                          ],
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
  }) {
    final top = taskTopOffset(start, dayStart);
    final height = taskHeight(duration);
    return Positioned(
      top: top,
      left: left,
      width: width,
      height: height,
      child: Container(
        margin: const EdgeInsets.only(right: 4, bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      ),
    );
  }

  Widget _eventTile(FixedEvent event) => Card(
    child: ListTile(
      leading: const Icon(Icons.event_available_outlined, color: _muted),
      title: Text(event.title),
      subtitle: Text('${_clock(event.start)}–${_clock(event.end)} · Fixe'),
      dense: true,
    ),
  );
}
