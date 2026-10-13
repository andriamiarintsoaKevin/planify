part of '../../main.dart';

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
      ).copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

class _LoadErrorView extends StatelessWidget {
  const _LoadErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 36, color: _danger),
          const SizedBox(height: 12),
          const Text(
            'Impossible de charger vos données',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

class _TaskFormResult {
  const _TaskFormResult({this.task, this.deleteId});

  final PlanoTask? task;
  final String? deleteId;
}

class _PlannerOptions {
  const _PlannerOptions({
    required this.respectLunch,
    required this.lunchDurationMinutes,
    required this.prioritizeHighPriority,
    required this.addBuffer,
  });

  final bool respectLunch;
  final int lunchDurationMinutes;
  final bool prioritizeHighPriority;
  final bool addBuffer;
}

class _PlanApproval {
  const _PlanApproval({required this.lockedTaskIds, this.editOptions = false});

  final Set<String> lockedTaskIds;
  final bool editOptions;
}

const _projectPalette = <Color>[
  Color(0xFF3B82F6),
  Color(0xFFEC4899),
  Color(0xFF22C55E),
  Color(0xFF8B5CF6),
  Color(0xFFF97316),
];

Color _projectColor(String project) {
  if (project.isEmpty) return _primary;
  final colorIndex = project.codeUnits.fold<int>(
    0,
    (sum, character) => sum + character,
  );
  return _projectPalette[colorIndex % _projectPalette.length];
}

Color _priorityColor(BuildContext context, TaskPriority priority) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (priority) {
    TaskPriority.low =>
      dark ? const Color(0xFF57D6B1) : const Color(0xFF07836F),
    TaskPriority.medium =>
      dark ? const Color(0xFF9AA5FF) : const Color(0xFF5262D8),
    TaskPriority.high =>
      dark ? const Color(0xFFFF8585) : const Color(0xFFC63845),
  };
}

Color _priorityTint(BuildContext context, TaskPriority priority) =>
    _priorityColor(context, priority).withValues(
      alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.1,
    );

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

InputDecoration _inputDecoration(String hint, BuildContext context) =>
    InputDecoration(
  hintText: hint,
  filled: true,
  fillColor: Theme.of(context).colorScheme.surfaceContainer,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
  ),
);

String _priorityLabel(TaskPriority priority) => switch (priority) {
  TaskPriority.low => 'Basse',
  TaskPriority.medium => 'Normale',
  TaskPriority.high => 'Haute',
};

String _durationLabel(int minutes) {
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  if (hours == 0) return '$minutes min';
  if (remainingMinutes == 0) return '$hours h';
  return '$hours h $remainingMinutes min';
}

String _clock(DateTime dateTime) =>
    '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

String _taskTimeRangeOnDay(PlanoTask task, DateTime day) {
  final start = taskVisibleStartOnDay(task, day);
  final end = taskVisibleEndOnDay(task, day);
  final dayEnd = DateTime(day.year, day.month, day.day + 1);
  final continued = task.scheduledStart!.isBefore(start);
  final continuesTomorrow = task.scheduledEnd!.isAfter(dayEnd);
  return '${continued ? 'Suite · ' : ''}${_clock(start)}–${_clock(end)}'
      '${continuesTomorrow ? ' · suite demain' : ''}';
}

String _formatDate(DateTime dateTime) =>
    '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';

DateTime _dateOnly(DateTime dateTime) =>
    DateTime(dateTime.year, dateTime.month, dateTime.day);

DateTime _atTime(DateTime date, int hour, int minute) =>
    DateTime(date.year, date.month, date.day, hour, minute);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
