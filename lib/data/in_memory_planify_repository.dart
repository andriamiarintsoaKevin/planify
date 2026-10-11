import '../domain/planner.dart';
import 'plano_repository.dart';

class InMemoryPlanifyRepository implements PlanoRepository {
  List<PlanoTask> _tasks = [];
  bool _darkMode = false;

  @override
  Future<List<PlanoTask>> loadTasks() async => List.unmodifiable(_tasks);

  @override
  Future<void> saveTasks(List<PlanoTask> tasks) async {
    _tasks = List.of(tasks);
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
}
