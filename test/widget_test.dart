import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planify/data/in_memory_planify_repository.dart';
import 'package:planify/domain/planner.dart';
import 'package:planify/main.dart';

void main() {
  testWidgets('affiche les notifications en haut avec une progression', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(PlanoApp(repository: InMemoryPlanifyRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter').last);
    await tester.pump();

    expect(find.text('Saisissez un titre pour la tâche'), findsOneWidget);
    final progressFinder = find.byType(LinearProgressIndicator);
    expect(progressFinder, findsOneWidget);
    final initialProgress = tester.widget<LinearProgressIndicator>(
      progressFinder,
    );
    expect(initialProgress.value, greaterThan(0));

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Saisissez un titre pour la tâche'), findsNothing);
    expect(progressFinder, findsNothing);
  });

  testWidgets('démarre proprement avec une Inbox vide', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(PlanoApp(repository: InMemoryPlanifyRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Aujourd’hui'), findsWidgets);
    expect(find.text('Votre planning'), findsOneWidget);
    expect(find.text('Inbox'), findsOneWidget);

    await tester.tap(find.text('Inbox').last);
    await tester.pumpAndSettle();

    expect(
      find.text('Ajouter une tâche… ex. Appeler Léa demain'),
      findsOneWidget,
    );
    expect(find.text('0 à planifier'), findsOneWidget);
    expect(find.text('Votre Inbox est vide'), findsOneWidget);
    expect(find.text('Planifier automatiquement les 4 tâches'), findsNothing);
  });

  testWidgets('bloque l’analyse IA tant que le consentement est refusé', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(PlanoApp(repository: InMemoryPlanifyRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Réglages').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assistant IA'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'Préparer une présentation',
    );
    await tester.tap(find.text('Analyser'));
    await tester.pumpAndSettle();

    expect(
      find.text('Votre texte est envoyé à Google (Gemini) pour être analysé'),
      findsOneWidget,
    );
    await tester.tap(find.text('Pas maintenant'));
    await tester.pumpAndSettle();

    expect(find.text('Créer avec l’IA'), findsOneWidget);
    expect(
      find.text('Connectez-vous pour utiliser l’analyse IA.'),
      findsNothing,
    );

    await tester.tap(find.text('Analyser'));
    await tester.pumpAndSettle();
    expect(
      find.text('Votre texte est envoyé à Google (Gemini) pour être analysé'),
      findsOneWidget,
    );
  });

  testWidgets('permet de prévisualiser puis valider un plan', (
    WidgetTester tester,
  ) async {
    final repository = InMemoryPlanifyRepository();
    await repository.saveTasks([
      PlanoTask(
        id: 'plan-preview',
        title: 'Préparer le test Planify',
        durationMinutes: 30,
      ),
      const PlanoTask(
        id: 'plan-too-long',
        title: 'Tâche trop longue',
        durationMinutes: 25 * 60,
      ),
    ]);
    await tester.pumpWidget(PlanoApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Choisir une date'));
    await tester.pumpAndSettle();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    await tester.tap(find.text('${tomorrow.day}').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inbox').last);
    await tester.pumpAndSettle();
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();

    expect(find.text('Préparer le test Planify'), findsOneWidget);

    const planButtonLabel = 'Planifier automatiquement les 2 tâches';
    await tester.ensureVisible(find.text(planButtonLabel));
    await tester.tap(find.text(planButtonLabel));
    await tester.pumpAndSettle();

    expect(find.text('Préparer le plan'), findsOneWidget);
    expect(
      tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .every((toggle) => !toggle.value),
      isTrue,
    );
    await tester.ensureVisible(find.text('Générer le plan'));
    await tester.tap(find.text('Générer le plan'));
    await tester.pumpAndSettle();

    expect(find.text('Plan proposé'), findsOneWidget);
    expect(find.text('Tâche trop longue'), findsOneWidget);
    expect(
      find.text('Durée supérieure au temps libre disponible.'),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Modifier'));
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    expect(find.text('Préparer le plan'), findsOneWidget);
    await tester.ensureVisible(find.text('Générer le plan'));
    await tester.tap(find.text('Générer le plan'));
    await tester.pumpAndSettle();
    expect(find.text('Plan proposé'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Valider le plan'), findsOneWidget);
    await tester.tap(find.text('Valider le plan'));
    await tester.pumpAndSettle();

    expect(find.text('Votre planning'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    final restoredTasks = await repository.loadTasks();
    final restoredTask = restoredTasks.singleWhere(
      (task) => task.id == 'plan-preview',
    );
    final stillUnplaced = restoredTasks.singleWhere(
      (task) => task.id == 'plan-too-long',
    );
    expect(restoredTask.status, TaskStatus.inbox);
    expect(restoredTask.scheduledStart, isNull);
    expect(restoredTask.plannedEnd, isNull);
    expect(stillUnplaced.status, TaskStatus.inbox);
  });

  testWidgets(
    'la fiche est en lecture seule et le formulaire limite la durée',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        PlanoApp(repository: InMemoryPlanifyRepository()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Durée estimée'), findsOneWidget);
      expect(
        find.text(
          'De 15 min à 4 h. Une durée en heures peut être décimale, par exemple 1,5 h.',
        ),
        findsOneWidget,
      );
      expect(find.text('Deadline'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'Tâche sans durée');
      await tester.tap(find.text('Ajouter').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inbox').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tâche sans durée'));
      await tester.pumpAndSettle();

      expect(find.text('Durée estimée'), findsNothing);
      await tester.tap(find.text('Modifier la tâche'));
      await tester.pumpAndSettle();

      expect(find.text('Modifier la tâche'), findsOneWidget);
      expect(find.text('Durée estimée'), findsOneWidget);
      expect(find.text('Deadline'), findsNothing);
    },
  );

  testWidgets('convertit une durée saisie en heures en minutes', (
    WidgetTester tester,
  ) async {
    final repository = InMemoryPlanifyRepository();
    await tester.pumpWidget(PlanoApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final durationField = find.byKey(const ValueKey('task-duration-input'));
    await tester.enterText(
      find.descendant(of: durationField, matching: find.byType(TextField)),
      '90',
    );
    await tester.tap(find.text('Heures'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: durationField,
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      '1,5',
    );
    await tester.tap(find.text('Minutes'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: durationField,
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      '90',
    );

    await tester.tap(find.text('Heures'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(of: durationField, matching: find.byType(TextField)),
      '2',
    );
    await tester.enterText(
      find.byType(TextField).first,
      'Tâche de deux heures',
    );
    await tester.tap(find.text('Ajouter').last);
    await tester.pumpAndSettle();

    final savedTask = (await repository.loadTasks()).single;
    expect(savedTask.durationMinutes, 120);
  });

  testWidgets('les champs du formulaire s’adaptent au thème sombre', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(PlanoApp(repository: InMemoryPlanifyRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Réglages').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apparence sombre'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Apparence sombre'))).brightness,
      Brightness.dark,
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    final projectField = tester.widget<InputDecorator>(
      find.byType(InputDecorator).first,
    );
    expect(projectField.decoration.fillColor, isNot(Colors.white));
    expect(
      Theme.of(tester.element(find.text('Nouvelle tâche'))).brightness,
      Brightness.dark,
    );
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey('task-duration-input')),
              matching: find.byType(TextField),
            ),
          )
          .keyboardType,
      TextInputType.number,
    );
    final darkScheme = Theme.of(tester.element(find.text('Nouvelle tâche')))
        .colorScheme;
    expect(darkScheme.onSurface, const Color(0xFFF4F5F7));
    expect(darkScheme.onSurfaceVariant, const Color(0xFFC0C6D2));
  });

  testWidgets(
    'la pause déjeuner est réglable et la feuille suit le thème sombre',
    (WidgetTester tester) async {
      final repository = InMemoryPlanifyRepository();
      await repository.saveTasks([
        for (var index = 0; index < 4; index++)
          PlanoTask(
            id: 'long-$index',
            title: 'Tâche longue $index',
            durationMinutes: 240,
          ),
      ]);
      await tester.pumpWidget(PlanoApp(repository: repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Choisir une date'));
      await tester.pumpAndSettle();
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      await tester.tap(find.text('${tomorrow.day}').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Réglages').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apparence sombre'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inbox').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text('Planifier automatiquement les 4 tâches'),
      );
      await tester.tap(find.text('Planifier automatiquement les 4 tâches'));
      await tester.pumpAndSettle();

      expect(
        Theme.of(tester.element(find.text('Préparer le plan'))).brightness,
        Brightness.dark,
      );
      await tester.tap(find.text('Réserver une pause déjeuner'));
      await tester.pumpAndSettle();
      final fortyMinuteChip = find.widgetWithText(ChoiceChip, '40 min');
      expect(fortyMinuteChip, findsOneWidget);
      await tester.tap(fortyMinuteChip);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(fortyMinuteChip).selected, isTrue);

      await tester.ensureVisible(find.text('Générer le plan'));
      await tester.tap(find.text('Générer le plan'));
      await tester.pumpAndSettle();
      expect(find.textContaining('13:10–17:10'), findsOneWidget);
    },
  );

  testWidgets('différencie visuellement les trois priorités dans l’Inbox', (
    WidgetTester tester,
  ) async {
    final repository = InMemoryPlanifyRepository();
    await repository.saveTasks([
      const PlanoTask(
        id: 'low',
        title: 'Priorité basse',
        priority: TaskPriority.low,
      ),
      const PlanoTask(
        id: 'medium',
        title: 'Priorité normale',
        priority: TaskPriority.medium,
      ),
      const PlanoTask(
        id: 'high',
        title: 'Priorité haute',
        priority: TaskPriority.high,
      ),
    ]);
    await tester.pumpWidget(PlanoApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inbox').last);
    await tester.pumpAndSettle();

    final circleColors = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>()
        .where((decoration) => decoration.shape == BoxShape.circle)
        .map((decoration) => decoration.color)
        .toSet();
    expect(circleColors, contains(const Color(0xFF07836F)));
    expect(circleColors, contains(const Color(0xFF5262D8)));
    expect(circleColors, contains(const Color(0xFFC63845)));
  });

  testWidgets('explique les limites sans afficher de faux événement', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(PlanoApp(repository: InMemoryPlanifyRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calendrier').last);
    await tester.pumpAndSettle();
    expect(find.text('Aucun élément prévu'), findsOneWidget);
    expect(find.text('Point client'), findsNothing);

    await tester.tap(find.text('Réglages').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Comprendre Planify'));
    await tester.tap(find.text('Comprendre Planify'));
    await tester.pumpAndSettle();

    expect(find.text('Que signifie « Inbox » ?'), findsOneWidget);
    expect(find.text('Ce que Planify sait faire ici'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(find.text('Ce qui n’est pas encore connecté'), findsOneWidget);
  });

  testWidgets('permet de choisir une date et une heure pour une tâche', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(PlanoApp(repository: InMemoryPlanifyRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -350));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Choisir une date et une heure'));
    await tester.tap(find.text('Choisir une date et une heure'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(find.text('Heure de début'), findsOneWidget);
  });

  testWidgets('signale en rouge deux tâches qui se chevauchent', (
    WidgetTester tester,
  ) async {
    final repository = InMemoryPlanifyRepository();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    final end = start.add(const Duration(hours: 1));
    await repository.saveTasks([
      PlanoTask(
        id: 'overlap-a',
        title: 'Tâche A',
        status: TaskStatus.scheduled,
        scheduledStart: start,
        plannedEnd: end,
      ),
      PlanoTask(
        id: 'overlap-b',
        title: 'Tâche B',
        status: TaskStatus.scheduled,
        scheduledStart: start,
        plannedEnd: end,
      ),
    ]);
    await tester.pumpWidget(PlanoApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calendrier').last);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.warning_amber_rounded), findsNWidgets(2));
  });
}
