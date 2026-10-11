import '../../domain/planner.dart';
import '../plano_repository.dart';

class DemoPlanoRepository implements PlanoRepository {
  DemoPlanoRepository({DateTime? currentDate})
    : _currentDate = _dateOnly(currentDate ?? DateTime.now()) {
    _tasks = [
      PlanoTask(
        id: 'task-1',
        title: 'Préparer la proposition commerciale',
        project: 'Client A',
        durationMinutes: 60,
        priority: TaskPriority.high,
        deadline: _atTime(_currentDate, 17, 0),
      ),
      const PlanoTask(
        id: 'task-2',
        title: 'Répondre aux retours du site',
        project: 'Studio',
        durationMinutes: 45,
        priority: TaskPriority.medium,
      ),
      const PlanoTask(
        id: 'task-3',
        title: 'Envoyer la facture de septembre',
        project: 'Personnel',
        durationMinutes: 30,
        priority: TaskPriority.low,
      ),
      PlanoTask(
        id: 'task-4',
        title: 'Revoir le brief du projet',
        project: 'Projet',
        durationMinutes: 90,
        priority: TaskPriority.high,
        deadline: _atTime(_currentDate, 18, 0),
      ),
    ];
  }

  final DateTime _currentDate;
  late List<PlanoTask> _tasks;
  WorkSchedule _workSchedule = const WorkSchedule(
    startMinute: 9 * 60,
    endMinute: 18 * 60,
  );

  @override
  Future<List<PlanoTask>> loadTasks() async => List.unmodifiable(_tasks);

  @override
  Future<void> saveTasks(List<PlanoTask> tasks) async {
    _tasks = List.of(tasks);
  }

  @override
  Future<List<FixedEvent>> loadEvents(DateTime date) async => [
    FixedEvent(
      title: 'Point client',
      start: _atTime(date, 11, 0),
      end: _atTime(date, 11, 45),
      isDemo: true,
    ),
  ];

  @override
  Future<WorkSchedule> loadWorkSchedule() async => _workSchedule;

  @override
  Future<void> saveWorkSchedule(WorkSchedule schedule) async {
    _workSchedule = schedule;
  }
}

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

DateTime _atTime(DateTime date, int hour, int minute) =>
    DateTime(date.year, date.month, date.day, hour, minute);
