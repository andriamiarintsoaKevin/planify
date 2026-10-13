part of '../../main.dart';

class _TaskDetailsSheet extends StatelessWidget {
  const _TaskDetailsSheet({
    required this.task,
    required this.canEdit,
    required this.onEdit,
  });

  final PlanoTask task;
  final bool canEdit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(context, task.priority);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .88,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              22,
              12,
              22,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 5,
                      height: 52,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        task.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _badge(
                      _priorityLabel(task.priority),
                      _priorityTint(context, task.priority),
                      color,
                    ),
                    _badge(
                      _durationLabel(task.durationMinutes ?? 30),
                      Theme.of(context).colorScheme.surfaceContainer,
                      Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    if (task.isLocked)
                      _badge(
                        'Horaire verrouillé',
                        Theme.of(context).colorScheme.surfaceContainer,
                        Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  ],
                ),
                if (task.scheduledStart != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${_formatDate(task.scheduledStart!)} · '
                            '${_clock(task.scheduledStart!)}–'
                            '${_clock(task.scheduledEnd ?? task.scheduledStart!)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (task.project.isNotEmpty)
                  _detailRow(context, Icons.folder_outlined, task.project),
                if (task.reminderEnabled)
                  _detailRow(
                    context,
                    Icons.notifications_active_outlined,
                    task.scheduledStart == null
                        ? 'Rappel activé après planification'
                        : 'Rappel activé à l’heure de début',
                  ),
                if (task.notes.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Notes',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(task.notes, style: const TextStyle(height: 1.4)),
                ],
                const SizedBox(height: 24),
                if (canEdit)
                  FilledButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Modifier la tâche'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: _primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  )
                else
                  const Center(
                    child: Text('Une tâche passée est consultable uniquement.'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, IconData icon, String label) =>
      Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Row(
          children: [
            Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(label)),
          ],
        ),
      );
}
