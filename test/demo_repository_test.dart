import 'package:flutter_test/flutter_test.dart';
import 'package:planify/data/demo/demo_plano_repository.dart';
import 'package:planify/data/plano_repository.dart';
import 'package:planify/domain/planner.dart';

void main() {
  final selectedDate = DateTime(2026, 10, 12);

  test(
    'fournit les données de démonstration par l’interface repository',
    () async {
      final repository = DemoPlanoRepository(currentDate: selectedDate);

      final tasks = await repository.loadTasks();
      final events = await repository.loadEvents(selectedDate);
      final schedule = await repository.loadWorkSchedule();

      expect(tasks, hasLength(4));
      expect(events, hasLength(1));
      expect(events.single.isDemo, isTrue);
      expect(schedule.startMinute, 9 * 60);
      expect(schedule.endMinute, 18 * 60);
    },
  );

  test('sauvegarde tâches et horaires à travers le contrat', () async {
    final repository = DemoPlanoRepository(currentDate: selectedDate);
    const task = PlanoTask(id: 'new', title: 'Tâche ajoutée');
    const schedule = WorkSchedule(startMinute: 8 * 60, endMinute: 17 * 60);

    await repository.saveTasks([task]);
    await repository.saveWorkSchedule(schedule);

    expect((await repository.loadTasks()).single.id, 'new');
    expect((await repository.loadWorkSchedule()).startMinute, 8 * 60);
  });
}
