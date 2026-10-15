import '../domain/planner.dart';

abstract interface class TaskRepository {
  Future<List<PlanoTask>> loadTasks();

  Future<void> saveTasks(List<PlanoTask> tasks);

  Future<void> softDeleteTask(String id);
}
