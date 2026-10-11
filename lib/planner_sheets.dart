part of 'main.dart';

class _PlannerSetupSheet extends StatefulWidget {
  const _PlannerSetupSheet({
    required this.taskCount,
    required this.totalMinutes,
    required this.fixedCount,
    required this.workWindow,
  });

  final int taskCount;
  final int totalMinutes;
  final int fixedCount;
  final String workWindow;

  @override
  State<_PlannerSetupSheet> createState() => _PlannerSetupSheetState();
}

class _PlannerSetupSheetState extends State<_PlannerSetupSheet> {
  bool _respectLunch = true;
  bool _difficultMorning = true;
  bool _addBuffer = true;

  @override
  Widget build(BuildContext context) {
    final hours = widget.totalMinutes ~/ 60;
    final minutes = widget.totalMinutes % 60;
    return SafeArea(
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
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
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.schedule, color: _primary),
                  title: const Text('Journée de travail'),
                  subtitle: Text(widget.workWindow),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Respecter ma pause déjeuner'),
                value: _respectLunch,
                activeThumbColor: _primary,
                onChanged: (value) => setState(() => _respectLunch = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tâches difficiles le matin'),
                value: _difficultMorning,
                activeThumbColor: _primary,
                onChanged: (value) => setState(() => _difficultMorning = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Laisser 10 min entre les tâches'),
                value: _addBuffer,
                activeThumbColor: _primary,
                onChanged: (value) => setState(() => _addBuffer = value),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  _PlannerOptions(
                    respectLunch: _respectLunch,
                    difficultMorning: _difficultMorning,
                    addBuffer: _addBuffer,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Générer le plan'),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Le planning est calculé localement, sans IA.',
                  style: TextStyle(fontSize: 12, color: _muted),
                ),
              ),
            ],
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
          onPressed: () => Navigator.pop(context, false),
          icon: const Icon(Icons.close),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8F1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: _success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.result.unplaced.isEmpty
                        ? 'Tout est dans les temps'
                        : '${placements.length} tâches placées, ${widget.result.unplaced.length} à revoir',
                    style: const TextStyle(
                      color: Color(0xFF087A55),
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
                    color: _projectColor(placement.task.project),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                title: Text(
                  placement.task.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${_clock(placement.start)}–${_clock(placement.end)} · ${placement.task.project}${placement.task.durationMinutes == null ? ' · durée estimée' : ''}',
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
                        : _muted,
                  ),
                ),
              ),
            ),
          if (widget.result.unplaced.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4DE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ces tâches ne rentrent pas',
                    style: TextStyle(
                      color: Color(0xFF9A5B00),
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
                        subtitle: const Text('Garder dans l’Inbox'),
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
              leading: const Icon(Icons.lightbulb_outline, color: _primary),
              title: const Text('Pourquoi ce plan ?'),
              children: [
                for (final reason in widget.result.explanations)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.check, color: _success, size: 18),
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
                leading: const Icon(
                  Icons.event_available_outlined,
                  color: _muted,
                ),
                title: Text(event.title),
                subtitle: Text(
                  '${_clock(event.start)}–${_clock(event.end)} · Fixe',
                ),
              ),
            ),
          const SizedBox(height: 22),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
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
