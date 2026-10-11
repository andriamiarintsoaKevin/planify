part of '../../main.dart';

extension _PlanoCalendarScreen on _PlanoAppState {
  Widget _calendarPage() {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Calendrier',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _chooseDate,
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
        children: [
          Text(
            _formatDate(_selectedDate),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          _dayStrip(),
          const SizedBox(height: 8),
          if (scheduled.isEmpty && _events.isEmpty)
            _emptyCard(
              icon: Icons.calendar_today_outlined,
              title: 'Aucun élément prévu',
              message: 'Votre calendrier est libre pour cette journée.',
            )
          else ...[
            for (final event in _events) _eventTile(event),
            for (final task in scheduled)
              Card(
                color: _isTaskPast(task)
                    ? _muted.withValues(alpha: 0.08)
                    : null,
                child: Opacity(
                  opacity: _isTaskPast(task) ? 0.45 : 1,
                  child: ListTile(
                    leading: Container(
                      width: 4,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _projectColor(task.project),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    title: Text(task.title),
                    subtitle: Text(
                      '${_clock(task.scheduledStart!)}–${_clock(task.scheduledEnd!)}'
                      '${task.project.isEmpty ? '' : ' · ${task.project}'}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_hasScheduleConflict(task))
                          const Tooltip(
                            message: 'Cette tâche chevauche une autre tâche',
                            child: Icon(
                              Icons.warning_amber_rounded,
                              color: _danger,
                            ),
                          ),
                        if (task.isLocked)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.lock_outline, size: 18),
                          ),
                      ],
                    ),
                    onTap: _isTaskPast(task)
                        ? null
                        : () => _showTaskEditor(task: task),
                    enabled: !_isTaskPast(task),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Aucun calendrier connecté',
              style: TextStyle(fontSize: 12, color: _muted),
            ),
          ),
        ],
      ),
    );
  }
}
