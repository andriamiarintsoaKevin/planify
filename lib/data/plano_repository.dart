import '../domain/planner.dart';

abstract interface class PlanoRepository {
  Future<List<PlanoTask>> loadTasks();

  Future<void> saveTasks(List<PlanoTask> tasks);

  Future<List<FixedEvent>> loadEvents(DateTime date);

  Future<bool> loadDarkMode();

  Future<void> saveDarkMode(bool enabled);
}
