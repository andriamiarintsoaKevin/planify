import 'package:flutter_test/flutter_test.dart';
import 'package:planify/data/in_memory_planify_repository.dart';
import 'package:planify/data/plano_repository.dart';
import 'package:planify/domain/planner.dart';

void main() {
  final selectedDate = DateTime(2026, 10, 12);

  test(
    'démarre sans tâches ni événements avec des horaires par défaut',
    () async {
      final repository = InMemoryPlanifyRepository();

      final tasks = await repository.loadTasks();
      final events = await repository.loadEvents(selectedDate);
      final schedule = await repository.loadWorkSchedule();

      expect(tasks, isEmpty);
      expect(events, isEmpty);
      expect(schedule.startMinute, 9 * 60);
      expect(schedule.endMinute, 18 * 60);
      expect(await repository.loadDarkMode(), isFalse);
    },
  );

  test('conserve les tâches et horaires pendant la session', () async {
    final repository = InMemoryPlanifyRepository();
    const task = PlanoTask(id: 'new', title: 'Tâche ajoutée');
    const schedule = WorkSchedule(startMinute: 8 * 60, endMinute: 17 * 60);

    await repository.saveTasks([task]);
    await repository.saveWorkSchedule(schedule);
    await repository.saveDarkMode(true);

    expect((await repository.loadTasks()).single.id, 'new');
    expect((await repository.loadWorkSchedule()).startMinute, 8 * 60);
    expect(await repository.loadDarkMode(), isTrue);
  });
}
