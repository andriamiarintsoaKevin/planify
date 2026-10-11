import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planify/data/in_memory_planify_repository.dart';
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
    await tester.ensureVisible(find.text('Générer le plan'));
    await tester.tap(find.text('Générer le plan'));
    await tester.pumpAndSettle();

    expect(find.text('Plan proposé'), findsOneWidget);
    expect(find.text('Tout est dans les temps'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Valider le plan'), findsOneWidget);
    await tester.tap(find.text('Valider le plan'));
    await tester.pumpAndSettle();

    expect(find.text('Planning modifié'), findsOneWidget);
    expect(find.text('Votre planning'), findsOneWidget);
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
}
