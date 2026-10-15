import 'package:flutter_test/flutter_test.dart';
import 'package:planify/data/in_memory_planify_repository.dart';
import 'package:planify/data/task_id.dart';
import 'package:planify/domain/planner.dart';

void main() {
  final selectedDate = DateTime(2026, 10, 12);

  test('démarre sans tâches ni événements et avec le thème clair', () async {
    final repository = InMemoryPlanifyRepository();

    final tasks = await repository.loadTasks();
    final events = await repository.loadEvents(selectedDate);

    expect(tasks, isEmpty);
    expect(events, isEmpty);
    expect(await repository.loadDarkMode(), isFalse);
  });

  test('conserve les tâches et le thème pendant la session', () async {
    final repository = InMemoryPlanifyRepository();
    const task = PlanoTask(id: 'new', title: 'Tâche ajoutée');

    await repository.saveTasks([task]);
    await repository.saveDarkMode(true);

    expect((await repository.loadTasks()).single.id, 'new');
    expect(await repository.loadDarkMode(), isTrue);
  });

  test('génère des identifiants UUID v4', () {
    final firstId = generateTaskId();
    final secondId = generateTaskId();
    final uuidV4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    expect(firstId, matches(uuidV4));
    expect(secondId, matches(uuidV4));
    expect(secondId, isNot(firstId));
  });

  test('masque les tâches supprimées logiquement', () async {
    final repository = InMemoryPlanifyRepository();
    const task = PlanoTask(id: 'deleted', title: 'Tâche supprimée');

    await repository.saveTasks([task]);
    await repository.softDeleteTask(task.id);

    expect(await repository.loadTasks(), isEmpty);
  });
}
