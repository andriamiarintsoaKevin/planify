part of '../../main.dart';

class _PlannerSetupSheet extends StatefulWidget {
  const _PlannerSetupSheet({
    required this.taskCount,
    required this.totalMinutes,
    required this.fixedCount,
  });

  final int taskCount;
  final int totalMinutes;
  final int fixedCount;

  @override
  State<_PlannerSetupSheet> createState() => _PlannerSetupSheetState();
}

class _PlannerSetupSheetState extends State<_PlannerSetupSheet> {
  bool _respectLunch = false;
  int _lunchDurationMinutes = 30;
  bool _prioritizeHighPriority = false;
  bool _addBuffer = false;

  @override
  Widget build(BuildContext context) {
    final hours = widget.totalMinutes ~/ 60;
    final minutes = widget.totalMinutes % 60;
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Material(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Préparer le plan',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.taskCount} tâches · ${hours}h ${minutes}min · ${widget.fixedCount} événement fixe',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Les 24 heures sont disponibles. Active uniquement les règles que tu souhaites appliquer.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Réserver une pause déjeuner'),
                  value: _respectLunch,
                  activeThumbColor: colorScheme.primary,
                  onChanged: (value) => setState(() => _respectLunch = value),
                ),
                if (_respectLunch) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Durée de la pause · 12:30',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final duration in [15, 20, 25, 30, 35, 40])
                        ChoiceChip(
                          label: Text('$duration min'),
                          selected: _lunchDurationMinutes == duration,
                          onSelected: (_) =>
                              setState(() => _lunchDurationMinutes = duration),
                        ),
                    ],
                  ),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Planifier les priorités hautes en premier',
                  ),
                  value: _prioritizeHighPriority,
                  activeThumbColor: colorScheme.primary,
                  onChanged: (value) =>
                      setState(() => _prioritizeHighPriority = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Laisser 10 min entre les tâches'),
                  value: _addBuffer,
                  activeThumbColor: colorScheme.primary,
                  onChanged: (value) => setState(() => _addBuffer = value),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    _PlannerOptions(
                      respectLunch: _respectLunch,
                      lunchDurationMinutes: _lunchDurationMinutes,
                      prioritizeHighPriority: _prioritizeHighPriority,
                      addBuffer: _addBuffer,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Générer le plan'),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Le plan est généré automatiquement sur cet appareil.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanPreviewPage extends StatefulWidget {
  const _PlanPreviewPage({
    required this.result,
    required this.selectedDate,
    required this.events,
  });

  final PlanResult result;
  final DateTime selectedDate;
  final List<FixedEvent> events;

  @override
  State<_PlanPreviewPage> createState() => _PlanPreviewPageState();
}

class _PlanPreviewPageState extends State<_PlanPreviewPage> {
  final _lockedIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final placements = widget.result.placements;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Plan proposé',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop<_PlanApproval>(context),
          icon: const Icon(Icons.close),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.result.unplaced.isEmpty
                        ? 'Tout est dans les temps'
                        : '${placements.length} tâches placées, ${widget.result.unplaced.length} à revoir',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _formatDate(widget.selectedDate),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          for (final placement in placements)
            Card(
              child: ListTile(
                leading: Container(
                  width: 5,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _priorityColor(context, placement.task.priority),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                title: Text(
                  placement.task.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${_clock(placement.start)}–${_clock(placement.end)}'
                  ' · ${_priorityLabel(placement.task.priority)}'
                  '${placement.task.project.isEmpty ? '' : ' · ${placement.task.project}'}',
                ),
                trailing: IconButton(
                  tooltip: _lockedIds.contains(placement.task.id)
                      ? 'Déverrouiller cette proposition'
                      : 'Verrouiller cette proposition',
                  onPressed: () => setState(() {
                    if (!_lockedIds.add(placement.task.id)) {
                      _lockedIds.remove(placement.task.id);
                    }
                  }),
                  icon: Icon(
                    _lockedIds.contains(placement.task.id)
                        ? Icons.lock
                        : Icons.lock_open_outlined,
                    color: _lockedIds.contains(placement.task.id)
                        ? _primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          if (widget.result.unplaced.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ces tâches ne rentrent pas',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  for (final task in widget.result.unplaced)
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(task.title),
                        subtitle: Text(
                          widget.result.unplacedReasons[task.id] ??
                              'Garder dans l’Inbox',
                        ),
                        trailing: const Icon(Icons.inbox_outlined),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Card(
            child: ExpansionTile(
              leading: Icon(
                Icons.lightbulb_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Pourquoi ce plan ?'),
              children: [
                for (final reason in widget.result.explanations)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.tertiary,
                      size: 18,
                    ),
                    title: Text(reason, style: const TextStyle(fontSize: 13)),
                  ),
                if (widget.result.explanations.isEmpty)
                  const ListTile(
                    title: Text(
                      'Aucune tâche n’a pu être placée dans cette journée.',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final event in widget.events)
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.event_available_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: Text(event.title),
                subtitle: Text(
                  '${_clock(event.start)}–${_clock(event.end)} · Fixe',
                ),
              ),
            ),
          const SizedBox(height: 22),
          OutlinedButton(
            onPressed: () => Navigator.pop(
              context,
              _PlanApproval(
                lockedTaskIds: Set.of(_lockedIds),
                editOptions: true,
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Modifier'),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: placements.isEmpty
                ? null
                : () => Navigator.pop(
                    context,
                    _PlanApproval(lockedTaskIds: Set.of(_lockedIds)),
                  ),
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Valider le plan'),
          ),
        ],
      ),
    );
  }
}
