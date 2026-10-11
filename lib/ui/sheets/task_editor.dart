part of '../../main.dart';

class _QuickCapture extends StatefulWidget {
  const _QuickCapture({required this.onSubmit});

  final ValueChanged<String> onSubmit;

  @override
  State<_QuickCapture> createState() => _QuickCaptureState();
}

class _QuickCaptureState extends State<_QuickCapture> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    widget.onSubmit(value);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        hintText: 'Ajouter une tâche… ex. Appeler Léa demain',
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        prefixIcon: Icon(
          Icons.add_task_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        suffixIcon: IconButton(
          onPressed: _submit,
          tooltip: 'Ajouter',
          icon: const Icon(Icons.arrow_upward_rounded, color: _primary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 17,
          horizontal: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

class _TaskEditorSheet extends StatefulWidget {
  const _TaskEditorSheet({this.task, required this.initialScheduleDate});

  final PlanoTask? task;
  final DateTime initialScheduleDate;

  @override
  State<_TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<_TaskEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late int? _duration;
  late TaskPriority _priority;
  late String _project;
  late bool _locked;
  DateTime? _deadline;
  DateTime? _scheduledStart;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _title = TextEditingController(text: task?.title ?? '');
    _notes = TextEditingController(text: task?.notes ?? '');
    _duration = task?.durationMinutes ?? 30;
    _priority = task?.priority ?? TaskPriority.medium;
    _project = task?.project ?? '';
    _locked = task?.isLocked ?? false;
    _deadline = task?.deadline;
    _scheduledStart = task?.scheduledStart;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.task != null;
    final canLockSchedule =
        _scheduledStart != null;
    return DraggableScrollableSheet(
      initialChildSize: .88,
      minChildSize: .65,
      maxChildSize: .95,
      expand: false,
      builder: (context, controller) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
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
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                Expanded(
                  child: Text(
                    editing ? 'Modifier la tâche' : 'Nouvelle tâche',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: _save,
                  child: Text(
                    editing ? 'Enregistrer' : 'Ajouter',
                    style: const TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _title,
              autofocus: !editing,
              maxLines: 2,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText: 'Que faut-il faire ?',
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 14),
            const _FieldLabel('Projet'),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: _project,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration('Facultatif', context),
              onChanged: (value) => _project = value.trim(),
            ),
            const SizedBox(height: 20),
            const _FieldLabel('Planifier le'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _chooseSchedule,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                _scheduledStart == null
                    ? 'Choisir une date et une heure'
                    : '${_formatDate(_scheduledStart!)} à ${_clock(_scheduledStart!)}',
              ),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (_scheduledStart != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() {
                    _scheduledStart = null;
                    _locked = false;
                  }),
                  child: const Text('Retirer du planning'),
                ),
              ),
            const SizedBox(height: 20),
            const _FieldLabel('Deadline'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _chooseDeadline,
              icon: const Icon(Icons.event_outlined),
              label: Text(
                _deadline == null
                    ? 'Ajouter une échéance'
                    : '${_formatDate(_deadline!)} à ${_clock(_deadline!)}',
              ),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (_deadline != null && _scheduledStart != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Le créneau se terminera à la deadline.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (_deadline != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _deadline = null),
                  child: const Text('Retirer la deadline'),
                ),
              ),
            const SizedBox(height: 18),
            const _FieldLabel('Priorité'),
            const SizedBox(height: 8),
            SegmentedButton<TaskPriority>(
              segments: const [
                ButtonSegment(value: TaskPriority.low, label: Text('Basse')),
                ButtonSegment(
                  value: TaskPriority.medium,
                  label: Text('Normale'),
                ),
                ButtonSegment(value: TaskPriority.high, label: Text('Haute')),
              ],
              selected: {_priority},
              onSelectionChanged: (selection) =>
                  setState(() => _priority = selection.first),
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Verrouiller l’horaire'),
              subtitle: Text(canLockSchedule
                  ? 'Le planificateur ne déplacera pas cette tâche'
                  : 'Choisissez d’abord une date et une heure'),
              value: _locked,
              activeThumbColor: _primary,
              onChanged: canLockSchedule
                  ? (value) => setState(() => _locked = value)
                  : null,
            ),
            const SizedBox(height: 10),
            const _FieldLabel('Notes'),
            const SizedBox(height: 8),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: _inputDecoration('Ajouter des détails…', context),
            ),
            if (editing) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(
                  context,
                  _TaskFormResult(deleteId: widget.task!.id),
                ),
                icon: const Icon(Icons.delete_outline, color: _danger),
                label: const Text(
                  'Supprimer',
                  style: TextStyle(color: _danger),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _chooseDeadline() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _deadline ?? _dateOnly(now),
      firstDate: _dateOnly(now),
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
    );
    if (selected == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _deadline ?? DateTime(selected.year, selected.month, selected.day, 17),
      ),
    );
    if (time != null) {
      final deadline = DateTime(
        selected.year,
        selected.month,
        selected.day,
        time.hour,
        time.minute,
      );
      if (_scheduledStart != null && !deadline.isAfter(_scheduledStart!)) {
        _showFormMessage('La deadline doit être après le début de la tâche');
        return;
      }
      setState(() => _deadline = deadline);
    }
  }

  Future<void> _chooseSchedule() async {
    final now = DateTime.now();
    final firstDate = _dateOnly(now);
    final initialDate = _scheduledStart ?? widget.initialScheduleDate;
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: firstDate,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
      helpText: 'Date de la tâche',
    );
    if (selectedDate == null || !mounted) return;
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _scheduledStart == null
          ? TimeOfDay.fromDateTime(now)
          : TimeOfDay.fromDateTime(_scheduledStart!),
      helpText: 'Heure de début',
    );
    if (selectedTime == null || !mounted) return;
    final start = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    if (start.isBefore(now)) {
      _showFormMessage('Choisissez une date et une heure à venir');
      return;
    }
    if (_deadline != null && !_deadline!.isAfter(start)) {
      _showFormMessage('La deadline doit être après le début de la tâche');
      return;
    }
    final end = scheduledEndForTask(
      start: start,
      deadline: _deadline,
      durationMinutes: _duration,
    )!;
    if (_deadline == null && end.isAfter(_atTime(selectedDate, 24, 0))) {
      _showFormMessage('La tâche doit se terminer avant minuit');
      return;
    }
    setState(() => _scheduledStart = start);
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      _showFormMessage('Saisissez un titre pour la tâche');
      return;
    }
    final old = widget.task;
    if (_scheduledStart != null &&
        _deadline != null &&
        !_deadline!.isAfter(_scheduledStart!)) {
      _showFormMessage('La deadline doit être après le début de la tâche');
      return;
    }
    final scheduledEnd = scheduledEndForTask(
      start: _scheduledStart,
      deadline: _deadline,
      durationMinutes: _duration,
    );
    if (_scheduledStart != null &&
        _deadline == null &&
        scheduledEnd!.isAfter(_atTime(_scheduledStart!, 24, 0))) {
      _showFormMessage('La tâche doit se terminer avant minuit');
      return;
    }
    Navigator.pop(
      context,
      _TaskFormResult(
        task: PlanoTask(
          id: old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
          title: title,
          notes: _notes.text.trim(),
          durationMinutes: scheduledEnd == null
              ? _duration
              : scheduledEnd.difference(_scheduledStart!).inMinutes,
          priority: _priority,
          deadline: _deadline,
          status: _scheduledStart != null
              ? TaskStatus.scheduled
              : old?.status == TaskStatus.scheduled
              ? TaskStatus.inbox
              : old?.status ?? TaskStatus.inbox,
          scheduledStart: _scheduledStart,
          scheduledEnd: scheduledEnd,
          project: _project,
          isLocked: _locked && _scheduledStart != null,
          isAiProposed: old?.isAiProposed ?? false,
          isDurationEstimated: _duration == null ||
              (old?.isDurationEstimated ?? false),
        ),
      ),
    );
  }

  void _showFormMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }
}
