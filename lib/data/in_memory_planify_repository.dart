import '../domain/planner.dart';
import 'plano_repository.dart';
import 'task_repository.dart';

class InMemoryPlanifyRepository implements PlanoRepository, TaskRepository {
  final List<PlanoTask> _tasks = [];
  bool _darkMode = false;
  String? _calendarId;

  @override
  Future<List<PlanoTask>> loadTasks() async =>
      List.unmodifiable(_tasks.where((task) => task.deletedAt == null));

  @override
  Future<void> saveTasks(List<PlanoTask> tasks) async {
    final now = DateTime.now().toUtc();
    for (final task in tasks) {
      final index = _tasks.indexWhere((stored) => stored.id == task.id);
      if (index >= 0 && _tasks[index].deletedAt != null) continue;
      final existing = index >= 0 ? _tasks[index] : null;
      final persisted = task.copyWith(
        createdAt: existing?.createdAt ?? task.createdAt ?? now,
        updatedAt: now,
        deletedAt: existing?.deletedAt,
      );
      if (index < 0) {
        _tasks.add(persisted);
      } else {
        _tasks[index] = persisted;
      }
    }
  }

  @override
  Future<void> softDeleteTask(String id) async {
    final index = _tasks.indexWhere(
      (task) => task.id == id && task.deletedAt == null,
    );
    if (index < 0) return;
    final now = DateTime.now().toUtc();
    _tasks[index] = _tasks[index].copyWith(updatedAt: now, deletedAt: now);
  }

  @override
  Future<void> clearLocalAccountData({required bool deleteTasks}) async {
    if (!deleteTasks) return;
    _tasks.clear();
    _darkMode = false;
    _calendarId = null;
  }

  @override
  Future<List<FixedEvent>> loadEvents(DateTime date) async =>
      const <FixedEvent>[];

  @override
  Future<bool> loadDarkMode() async => _darkMode;

  @override
  Future<void> saveDarkMode(bool enabled) async {
    _darkMode = enabled;
  }

  @override
  Future<String?> loadCalendarId() async => _calendarId;

  @override
  Future<void> saveCalendarId(String? calendarId) async {
    _calendarId = calendarId;
  }
}
