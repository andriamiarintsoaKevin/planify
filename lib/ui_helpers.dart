part of 'main.dart';

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  );
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _muted,
      ),
    ),
  );
}

class _TaskFormResult {
  const _TaskFormResult({this.task, this.deleteId});

  final PlanoTask? task;
  final String? deleteId;
}

class _PlannerOptions {
  const _PlannerOptions({
    required this.respectLunch,
    required this.difficultMorning,
    required this.addBuffer,
  });

  final bool respectLunch;
  final bool difficultMorning;
  final bool addBuffer;
}

class _PlanApproval {
  const _PlanApproval({required this.lockedTaskIds});

  final Set<String> lockedTaskIds;
}

Color _projectColor(String project) => _projectColors[project] ?? _primary;

Widget _badge(String label, Color background, Color foreground) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(
    color: background,
    borderRadius: BorderRadius.circular(999),
  ),
  child: Text(
    label,
    style: TextStyle(
      color: foreground,
      fontSize: 11,
      fontWeight: FontWeight.w500,
    ),
  ),
);

InputDecoration _inputDecoration(String hint) => InputDecoration(
  hintText: hint,
  filled: true,
  fillColor: Colors.white,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: _border),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: _border),
  ),
);

String _priorityLabel(TaskPriority priority) => switch (priority) {
  TaskPriority.low => 'Basse',
  TaskPriority.medium => 'Normale',
  TaskPriority.high => 'Haute',
};

String _durationLabel(int minutes) => minutes == 60
    ? '1 h'
    : minutes == 120
    ? '2 h'
    : '$minutes min';

String _clock(DateTime dateTime) =>
    '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

String _timeOfDayLabel(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

String _formatDate(DateTime dateTime) =>
    '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';

DateTime _dateOnly(DateTime dateTime) =>
    DateTime(dateTime.year, dateTime.month, dateTime.day);

DateTime _atTime(DateTime date, int hour, int minute) =>
    DateTime(date.year, date.month, date.day, hour, minute);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
