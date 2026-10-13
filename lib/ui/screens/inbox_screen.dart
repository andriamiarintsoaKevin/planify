part of '../../main.dart';

extension _PlanoInboxScreen on _PlanoAppState {
  Widget _inboxPage() {
    final inbox =
        _tasks.where((task) => task.status == TaskStatus.inbox).toList()
          ..sort((a, b) {
            final aDeadline = a.deadline ?? DateTime(9999);
            final bDeadline = b.deadline ?? DateTime(9999);
            return aDeadline.compareTo(bDeadline);
          });
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Inbox',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Center(
              child: _badge(
                '${inbox.length} à planifier',
                Theme.of(context).colorScheme.primaryContainer,
                _primary,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Les tâches capturées restent ici jusqu’à leur planification.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: _QuickCapture(onSubmit: _captureTask),
          ),
          Expanded(
            child: inbox.isEmpty
                ? _emptyCard(
                    icon: Icons.check_circle_outline,
                    title: 'Votre Inbox est vide',
                    message: 'Ajoutez une tâche pour commencer.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    itemCount: inbox.length,
                    itemBuilder: (context, index) {
                      final task = inbox[index];
                      return Dismissible(
                        key: ValueKey(task.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 22),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: _danger,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                          ),
                        ),
                        onDismissed: (_) => _deleteTask(task),
                        child: _taskCard(task),
                      );
                    },
                  ),
          ),
          if (inbox.isNotEmpty)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.icon(
                      onPressed: _openPlannerSetup,
                      icon: const Icon(Icons.auto_awesome),
                      label: Text(
                        inbox.length == 1
                            ? 'Planifier automatiquement la tâche'
                            : 'Planifier automatiquement les ${inbox.length} tâches',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Aperçu avant validation',
                      style: const TextStyle(fontSize: 12).copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _taskCard(PlanoTask task) {
    final projectColor = _projectColor(task.project);
    final priorityColor = _priorityColor(context, task.priority);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: priorityColor.withValues(alpha: .65)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showTaskDetails(task),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 14, 10, 14),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: priorityColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 5,
                      children: [
                        if (task.project.isNotEmpty)
                          _badge(
                            task.project,
                            projectColor.withValues(alpha: .12),
                            projectColor,
                          ),
                        _badge(
                          _priorityLabel(task.priority),
                          _priorityTint(context, task.priority),
                          priorityColor,
                        ),
                        if (task.durationMinutes == null)
                          _badge(
                            'Durée manquante',
                            _priorityTint(context, TaskPriority.high),
                            _priorityColor(context, TaskPriority.high),
                          ),
                        if (task.durationMinutes != null)
                          _badge(
                            _durationLabel(task.durationMinutes!),
                            Theme.of(context).colorScheme.surfaceContainer,
                            Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        if (task.deadline != null)
                          _badge(
                            'Avant ${_clock(task.deadline!)}',
                            _priorityTint(context, TaskPriority.high),
                            _priorityColor(context, TaskPriority.high),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Planifier cette tâche',
                onPressed: () => _openPlannerSetup(onlyTask: task),
                icon: const Icon(
                  Icons.calendar_month_outlined,
                  color: _primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
