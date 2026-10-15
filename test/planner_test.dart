import 'package:flutter_test/flutter_test.dart';
import 'package:planify/domain/planner.dart';

void main() {
  final day = DateTime(2026, 10, 12);

  DateTime at(int hour, [int minute = 0]) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  PlanSettings settings({
    int bufferMinutes = 0,
    bool lunch = false,
    bool prioritizeHighPriority = false,
  }) => PlanSettings(
    dayStart: day,
    dayEnd: DateTime(day.year, day.month, day.day + 1),
    lunchStart: lunch ? at(12, 30) : null,
    lunchEnd: lunch ? at(13, 30) : null,
    bufferMinutes: bufferMinutes,
    prioritizeHighPriority: prioritizeHighPriority,
  );

  test('calcule la fin planifiée depuis le début et la durée', () {
    final start = DateTime(2026, 10, 11, 16);

    expect(
      plannedEndForTask(start: start, durationMinutes: 30),
      DateTime(2026, 10, 11, 16, 30),
    );
  });

  test('découpe un créneau de nuit entre ses deux journées', () {
    final task = PlanoTask(
      id: 'night',
      title: 'Tâche de nuit',
      status: TaskStatus.scheduled,
      scheduledStart: DateTime(2026, 10, 11, 23),
      plannedEnd: DateTime(2026, 10, 12, 6),
    );

    expect(taskOverlapsDay(task, DateTime(2026, 10, 11)), isTrue);
    expect(taskOverlapsDay(task, DateTime(2026, 10, 12)), isTrue);
    expect(taskDurationOnDay(task, DateTime(2026, 10, 11)), 60);
    expect(taskDurationOnDay(task, DateTime(2026, 10, 12)), 6 * 60);
    expect(
      taskVisibleStartOnDay(task, DateTime(2026, 10, 12)),
      DateTime(2026, 10, 12),
    );
    expect(
      taskVisibleEndOnDay(task, DateTime(2026, 10, 11)),
      DateTime(2026, 10, 12),
    );
  });

  test('ne planifie aucune tâche avant le début futur de la journée', () {
    final start = at(16);
    final result = generatePlan(
      tasks: const [PlanoTask(id: 'future', title: 'Tâche future')],
      fixedEvents: [],
      settings: PlanSettings(
        dayStart: start,
        dayEnd: DateTime(day.year, day.month, day.day + 1),
      ),
    );

    expect(result.placements.single.start.isBefore(start), isFalse);
    expect(result.placements.single.start, start);
  });

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
      settings: settings(lunch: true, prioritizeHighPriority: true),
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
    expect(result.placements.first.start, at(0));
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
            dueDate: at(0, 15),
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
      scheduledStart: at(0),
      plannedEnd: at(1),
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
    expect(result.placements.single.start, at(1));
    expect(result.unplaced, isEmpty);
  });

  test('ne planifie pas après la fin de la journée', () {
    final lockedTomorrow = PlanoTask(
      id: 'locked-tomorrow',
      title: 'Créneau du lendemain',
      status: TaskStatus.scheduled,
      scheduledStart: DateTime(day.year, day.month, day.day + 1, 10),
      plannedEnd: DateTime(day.year, day.month, day.day + 1, 11),
      isLocked: true,
    );
    final result = generatePlan(
      tasks: [
        lockedTomorrow,
        const PlanoTask(
          id: 'new',
          title: 'Nouvelle tâche',
          durationMinutes: 60,
        ),
      ],
      fixedEvents: [
        FixedEvent(title: 'Événement', start: day, end: at(23, 30)),
      ],
      settings: settings(),
    );

    expect(result.placements, isEmpty);
    expect(result.unplaced.map((task) => task.id), ['new']);
  });

  test('planifie de minuit à minuit lorsque les règles sont désactivées', () {
    final locked = PlanoTask(
      id: 'locked',
      title: 'Tâche déjà fixée',
      durationMinutes: 12 * 60,
      status: TaskStatus.scheduled,
      scheduledStart: at(0),
      plannedEnd: at(12),
      isLocked: true,
    );
    final result = generatePlan(
      tasks: [
        locked,
        const PlanoTask(
          id: 'new',
          title: 'Nouvelle tâche',
          durationMinutes: 30,
          priority: TaskPriority.high,
        ),
      ],
      fixedEvents: [],
      settings: settings(),
    );

    expect(result.placements.single.start, at(12));
    expect(
      result.explanations,
      isNot(
        contains('Nouvelle tâche a été favorisée en raison de sa priorité.'),
      ),
    );
  });

  test('applique une seule fois la marge lorsque cette règle est activée', () {
    final locked = PlanoTask(
      id: 'locked',
      title: 'Tâche fixe',
      durationMinutes: 12 * 60,
      status: TaskStatus.scheduled,
      scheduledStart: at(0),
      plannedEnd: at(12),
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
      settings: settings(bufferMinutes: 10),
    );

    expect(result.placements.single.start, at(12, 10));
  });

  test(
    'détecte les chevauchements de tâches et autorise les créneaux adjacents',
    () {
      final first = PlanoTask(
        id: 'first',
        title: 'Première tâche',
        status: TaskStatus.scheduled,
        scheduledStart: at(10),
        plannedEnd: at(11),
      );
      final overlapping = PlanoTask(
        id: 'overlap',
        title: 'Tâche simultanée',
        status: TaskStatus.scheduled,
        scheduledStart: at(10, 30),
        plannedEnd: at(11, 30),
      );
      final adjacent = PlanoTask(
        id: 'adjacent',
        title: 'Tâche suivante',
        status: TaskStatus.scheduled,
        scheduledStart: at(11),
        plannedEnd: at(12),
      );

      expect(hasScheduleOverlap(first, [overlapping]), isTrue);
      expect(hasScheduleOverlap(first, [first, adjacent]), isFalse);
    },
  );

  test('considère une tâche passée uniquement après la fin de son créneau', () {
    final task = PlanoTask(
      id: 'past',
      title: 'Tâche terminée',
      status: TaskStatus.scheduled,
      scheduledStart: at(9),
      plannedEnd: at(10),
    );

    expect(isTaskPast(task, at(9, 59)), isFalse);
    expect(isTaskPast(task, at(10)), isTrue);
    expect(
      isTaskPast(task.copyWith(status: TaskStatus.inbox), at(11)),
      isFalse,
    );
  });

  test('n’impose pas la priorité haute sans activer cette règle', () {
    final tasks = [
      const PlanoTask(
        id: 'high',
        title: 'Priorité haute',
        priority: TaskPriority.high,
        durationMinutes: 30,
      ),
      const PlanoTask(
        id: 'low',
        title: 'Priorité basse',
        priority: TaskPriority.low,
        durationMinutes: 60,
      ),
    ];
    final defaultPlan = generatePlan(
      tasks: tasks,
      fixedEvents: [],
      settings: settings(),
    );
    final prioritizedPlan = generatePlan(
      tasks: tasks,
      fixedEvents: [],
      settings: settings(prioritizeHighPriority: true),
    );

    expect(defaultPlan.placements.first.task.id, 'low');
    expect(prioritizedPlan.placements.first.task.id, 'high');
  });

  test('calcule les dimensions de timeline à 72 pixels par heure', () {
    expect(taskTopOffset(at(10, 30), at(8)), 180);
    expect(taskHeight(60), 72);
    expect(taskHeight(15), 28);
  });
}
