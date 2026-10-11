import 'package:flutter_test/flutter_test.dart';
import 'package:planify/planner.dart';

void main() {
  final day = DateTime(2026, 10, 12);

  DateTime at(int hour, [int minute = 0]) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  PlanSettings settings({
    int bufferMinutes = 10,
    bool lunch = true,
    bool difficultTasksInMorning = true,
  }) => PlanSettings(
    workStart: at(9),
    workEnd: at(18),
    lunchStart: lunch ? at(12, 30) : null,
    lunchEnd: lunch ? at(13, 30) : null,
    bufferMinutes: bufferMinutes,
    difficultTasksInMorning: difficultTasksInMorning,
  );

  test('place les tâches sans chevaucher les événements ni la pause', () {
    final result = generatePlan(
      tasks: [
        const PlanoTask(
          id: 'a',
          title: 'Proposition',
          durationMinutes: 60,
          priority: TaskPriority.high,
        ),
        const PlanoTask(id: 'b', title: 'Réponse', durationMinutes: 45),
      ],
      fixedEvents: [
        FixedEvent(title: 'Réunion', start: at(11), end: at(11, 45)),
      ],
      settings: settings(),
    );

    expect(result.unplaced, isEmpty);
    expect(result.placements, hasLength(2));
    expect(result.explanations, hasLength(3));
    for (final placement in result.placements) {
      expect(
        placement.start.isBefore(at(12, 30)) ||
            !placement.start.isBefore(at(13, 30)),
        isTrue,
      );
      expect(
        placement.end.isBefore(at(11)) || !placement.start.isBefore(at(11, 45)),
        isTrue,
      );
    }
    expect(result.placements.first.start, at(9));
    expect(result.placements.first.task.title, 'Proposition');
  });

  test(
    'ne place jamais une tâche après sa deadline et utilise 30 min par défaut',
    () {
      final result = generatePlan(
        tasks: [
          PlanoTask(
            id: 'late',
            title: 'En retard',
            durationMinutes: 90,
            deadline: at(10),
          ),
          const PlanoTask(id: 'estimated', title: 'Durée inconnue'),
        ],
        fixedEvents: [],
        settings: settings(lunch: false, bufferMinutes: 0),
      );

      expect(result.unplaced.map((task) => task.id), contains('late'));
      final estimated = result.placements.single;
      expect(estimated.task.id, 'estimated');
      expect(estimated.end.difference(estimated.start).inMinutes, 30);
    },
  );

  test('conserve le créneau d’une tâche verrouillée', () {
    final locked = PlanoTask(
      id: 'locked',
      title: 'Créneau bloqué',
      durationMinutes: 60,
      status: TaskStatus.scheduled,
      scheduledStart: at(9),
      scheduledEnd: at(10),
      isLocked: true,
    );
    final result = generatePlan(
      tasks: [
        locked,
        const PlanoTask(
          id: 'new',
          title: 'Nouvelle tâche',
          durationMinutes: 30,
        ),
      ],
      fixedEvents: [],
      settings: settings(lunch: false, bufferMinutes: 0),
    );

    expect(result.placements.single.task.id, 'new');
    expect(result.placements.single.start, at(10));
    expect(result.unplaced, isEmpty);
  });

  test('calcule les dimensions de timeline à 72 pixels par heure', () {
    expect(taskTopOffset(at(10, 30), at(8)), 180);
    expect(taskHeight(60), 72);
    expect(taskHeight(15), 28);
  });
}
