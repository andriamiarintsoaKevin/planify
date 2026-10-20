import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planify/data/auth_repository.dart';
import 'package:planify/data/entitlement_service.dart';
import 'package:planify/data/in_memory_planify_repository.dart';
import 'package:planify/domain/planner.dart';
import 'package:planify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('les réglages gratuits gardent le thème indigo par défaut', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(PlanoApp(repository: InMemoryPlanifyRepository()));
    await tester.pumpAndSettle();

    final defaultPrimary = buildPlanifyTheme(
      const AppearanceSettings(),
      proAccess: false,
    ).colorScheme.primary;
    expect(
      tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .theme!
          .colorScheme
          .primary,
      defaultPrimary,
    );

    await tester.tap(find.text('Réglages').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personnaliser l’apparence'));
    await tester.pumpAndSettle();
    expect(find.text('Pro'), findsWidgets);
    await tester.tap(find.text('Océan'));
    await tester.pumpAndSettle();

    expect(find.text('Option Pro'), findsOneWidget);
    expect(
      tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .theme!
          .colorScheme
          .primary,
      defaultPrimary,
    );
  });

  testWidgets('les choix Pro expirent visuellement sans perdre la sélection', (
    WidgetTester tester,
  ) async {
    var now = DateTime.utc(2030, 1, 1);
    final entitlement = EntitlementService(
      apiKey: 'test-public-key',
      appUserId: 'test-user',
      proEntitlementId: 'pro',
      provider: _AppearanceEntitlementProvider(
        ProEntitlementStatus(
          isActive: true,
          expiresAt: now.add(const Duration(hours: 1)),
          willRenew: true,
        ),
      ),
      cache: _MemoryAppearanceEntitlementCache(),
      clock: () => now,
    );
    await entitlement.initialize();
    await tester.pumpWidget(
      PlanoApp(
        repository: InMemoryPlanifyRepository(),
        entitlementService: entitlement,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Réglages').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personnaliser l’apparence'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Océan'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Compacte'));
    await tester.tap(find.text('Compacte'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Détaillé'));
    await tester.tap(find.text('Détaillé'));
    await tester.pumpAndSettle();

    final proPrimary = buildPlanifyTheme(
      const AppearanceSettings(theme: AppearanceTheme.ocean),
      proAccess: true,
    ).colorScheme.primary;
    expect(
      tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .theme!
          .colorScheme
          .primary,
      proPrimary,
    );

    now = now.add(const Duration(hours: 2));
    await tester.pump(const Duration(minutes: 1));
    await tester.pump();
    final freePrimary = buildPlanifyTheme(
      const AppearanceSettings(),
      proAccess: false,
    ).colorScheme.primary;
    expect(
      tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .theme!
          .colorScheme
          .primary,
      freePrimary,
    );

    final preferences = await SharedPreferences.getInstance();
    final saved = jsonDecode(
      preferences.getString('planify.appearance.v1')!,
    ) as Map<String, dynamic>;
    expect(saved['theme'], AppearanceTheme.ocean.name);
    expect(saved['density'], AppearanceDensity.compact.name);
    expect(saved['plannerDisplay'], PlannerDisplay.detailed.name);
    expect(find.text('Détaillé'), findsOneWidget);
    expect(find.text('Pro'), findsWidgets);
    entitlement.dispose();
  });

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

  testWidgets('exporte les tâches et réglages dans un JSON copiable', (
    WidgetTester tester,
  ) async {
    final repository = InMemoryPlanifyRepository();
    await repository.saveTasks([
      PlanoTask(
        id: 'export-task',
        title: 'Préparer le dossier',
        dueDate: DateTime(2026, 10, 20),
      ),
    ]);
    await repository.saveDarkMode(true);
    await repository.saveCalendarId('calendar-123');
    await tester.pumpWidget(PlanoApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Réglages').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Exporter mes données'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Exporter mes données'));
    await tester.pumpAndSettle();

    final jsonText = tester
        .widget<SelectableText>(find.byType(SelectableText))
        .data!;
    final export = jsonDecode(jsonText) as Map<String, dynamic>;
    final task = (export['tasks'] as List).single as Map<String, dynamic>;
    final settings = export['settings'] as Map<String, dynamic>;

    expect(export['formatVersion'], 1);
    expect(task['id'], 'export-task');
    expect(task['title'], 'Préparer le dossier');
    expect(task['dueDate'], '2026-10-20T00:00:00.000');
    expect(settings['darkMode'], isTrue);
    expect(settings['calendarId'], 'calendar-123');
    expect(settings['aiGeminiConsentGranted'], isFalse);
    expect(find.text('Copier le JSON'), findsOneWidget);
  });

  testWidgets(
    'confirme la suppression serveur avant de proposer la conservation locale',
    (WidgetTester tester) async {
      final events = <String>[];
      final repository = _TrackingPlanifyRepository(events);
      await repository.saveTasks(const [
        PlanoTask(id: 'local-task', title: 'Tâche conservée'),
      ]);
      final authRepository = _FakeAuthRepository(events);
      await tester.pumpWidget(
        PlanoApp(repository: repository, authRepository: authRepository),
      );
      await tester.pumpAndSettle();

      await _openAccountDeletion(tester);
      expect(find.text('Supprimer définitivement le compte ?'), findsOneWidget);
      expect(events, isEmpty);

      await tester.tap(find.text('Supprimer définitivement'));
      await tester.pumpAndSettle();
      expect(events, ['delete-account']);
      expect(authRepository.currentUser, isNull);
      expect(find.text('Que faire des données locales ?'), findsOneWidget);

      await tester.tap(find.text('Garder localement'));
      await tester.pumpAndSettle();

      expect(events, ['delete-account', 'clear-local-keep']);
      expect((await repository.loadTasks()).single.id, 'local-task');
      expect(authRepository.currentUser, isNull);
    },
  );

  testWidgets('efface les tâches locales après le choix post-suppression', (
    WidgetTester tester,
  ) async {
    final events = <String>[];
    final repository = _TrackingPlanifyRepository(events);
    await repository.saveTasks(const [
      PlanoTask(id: 'local-task', title: 'Tâche à effacer'),
    ]);
    final authRepository = _FakeAuthRepository(events);
    await tester.pumpWidget(
      PlanoApp(repository: repository, authRepository: authRepository),
    );
    await tester.pumpAndSettle();

    await _openAccountDeletion(tester);
    await tester.tap(find.text('Supprimer définitivement'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tout effacer'));
    await tester.tap(find.widgetWithText(FilledButton, 'Tout effacer'));
    await tester.pumpAndSettle();

    expect(find.text('Que faire des données locales ?'), findsNothing);
    expect(events, ['delete-account', 'clear-local-delete']);
    expect(await repository.loadTasks(), isEmpty);
    expect(authRepository.currentUser, isNull);
  });

  testWidgets('bloque l’analyse IA tant que le consentement est refusé', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(PlanoApp(repository: InMemoryPlanifyRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Réglages').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Assistant IA'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
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
    await tester.scrollUntilVisible(
      find.text('Comprendre Planify'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
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

Future<void> _openAccountDeletion(WidgetTester tester) async {
  await tester.tap(find.text('Réglages').last);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('Mes données'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  expect(find.text('Mes données'), findsOneWidget);
  await tester.scrollUntilVisible(
    find.text('Supprimer mon compte'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text('Supprimer mon compte'));
  await tester.tap(find.text('Supprimer mon compte'));
  await tester.pumpAndSettle();
}

class _TrackingPlanifyRepository extends InMemoryPlanifyRepository {
  _TrackingPlanifyRepository(this.events);

  final List<String> events;

  @override
  Future<void> clearLocalAccountData({required bool deleteTasks}) {
    events.add(deleteTasks ? 'clear-local-delete' : 'clear-local-keep');
    return super.clearLocalAccountData(deleteTasks: deleteTasks);
  }
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.events);

  final List<String> events;
  User? _user = User.fromJson({
    'id': '00000000-0000-4000-8000-000000000001',
    'aud': 'authenticated',
    'created_at': DateTime.utc(2026).toIso8601String(),
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
  });

  @override
  User? get currentUser => _user;

  @override
  Stream<AuthState> get authStateChanges => const Stream<AuthState>.empty();

  @override
  Future<void> deleteAccount() async {
    events.add('delete-account');
    _user = null;
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {}
}

class _AppearanceEntitlementProvider implements EntitlementProvider {
  _AppearanceEntitlementProvider(this.status);

  final ProEntitlementStatus status;

  @override
  Future<void> configure({
    required String apiKey,
    required String appUserId,
  }) async {}

  @override
  Future<ProEntitlementStatus> fetchProEntitlement(
    String entitlementId,
  ) async => status;
}

class _MemoryAppearanceEntitlementCache implements EntitlementCache {
  EntitlementSnapshot? snapshot;

  @override
  Future<EntitlementSnapshot?> read(String appUserId) async => snapshot;

  @override
  Future<void> write(String appUserId, EntitlementSnapshot snapshot) async {
    this.snapshot = snapshot;
  }
}
