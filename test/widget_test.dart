import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planify/data/in_memory_planify_repository.dart';
import 'package:planify/domain/planner.dart';
import 'package:planify/main.dart';

void main() {
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

  testWidgets('permet de prévisualiser puis valider un plan', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(PlanoApp(repository: InMemoryPlanifyRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inbox').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      'Préparer le test Planify',
    );
    await tester.tap(find.byTooltip('Ajouter'));
    await tester.pumpAndSettle();
    expect(find.text('Préparer le test Planify'), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Planifier automatiquement la tâche'));
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
    final scheduleText = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .firstWhere(
          (text) => RegExp(r'^\d{2}:\d{2}–\d{2}:\d{2}').hasMatch(text),
        );
    final startClock = scheduleText.split('–').first.split(':');
    final scheduledMinutes =
        int.parse(startClock[0]) * 60 + int.parse(startClock[1]);
    final now = DateTime.now();
    expect(scheduledMinutes, greaterThanOrEqualTo(now.hour * 60 + now.minute));
    expect(find.text('Tout est dans les temps'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
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

    expect(find.text('Planning modifié'), findsOneWidget);
    expect(find.text('Votre planning'), findsOneWidget);
  });

  testWidgets('masque le champ de durée à la création et à la modification', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(PlanoApp(repository: InMemoryPlanifyRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Durée estimée'), findsNothing);
    expect(find.text('Sans durée'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'Tâche sans durée');
    await tester.tap(find.text('Ajouter').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inbox').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tâche sans durée'));
    await tester.pumpAndSettle();

    expect(find.text('Modifier la tâche'), findsOneWidget);
    expect(find.text('Durée estimée'), findsNothing);
    expect(find.text('Sans durée'), findsNothing);
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
    final darkScheme = Theme.of(
      tester.element(find.text('Nouvelle tâche')),
    ).colorScheme;
    expect(darkScheme.onSurface, const Color(0xFFF4F5F7));
    expect(darkScheme.onSurfaceVariant, const Color(0xFFC0C6D2));
  });

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
        scheduledEnd: end,
      ),
      PlanoTask(
        id: 'overlap-b',
        title: 'Tâche B',
        status: TaskStatus.scheduled,
        scheduledStart: start,
        scheduledEnd: end,
      ),
    ]);
    await tester.pumpWidget(PlanoApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calendrier').last);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.warning_amber_rounded), findsNWidgets(2));
  });
}
