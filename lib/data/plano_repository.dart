import '../domain/planner.dart';

class WorkSchedule {
  const WorkSchedule({
    required this.startMinute,
    required this.endMinute,
  }) : assert(startMinute >= 0 && startMinute < 1440),
       assert(endMinute > startMinute && endMinute <= 1440);

  final int startMinute;
  final int endMinute;
}

abstract interface class PlanoRepository {
  Future<List<PlanoTask>> loadTasks();

  Future<void> saveTasks(List<PlanoTask> tasks);

  Future<List<FixedEvent>> loadEvents(DateTime date);

  Future<WorkSchedule> loadWorkSchedule();

  Future<void> saveWorkSchedule(WorkSchedule schedule);

  Future<bool> loadDarkMode();

  Future<void> saveDarkMode(bool enabled);
}
