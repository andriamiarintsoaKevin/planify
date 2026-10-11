import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planify/main.dart';

void main() {
  testWidgets('affiche les sections principales en français', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PlanoApp());
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
    expect(find.text('Planifier automatiquement les 4 tâches'), findsOneWidget);
  });

  testWidgets('permet de prévisualiser puis valider un plan', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PlanoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inbox').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Planifier automatiquement les 4 tâches'));
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

  testWidgets('explique le prototype et identifie le faux événement', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PlanoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calendrier').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Exemple fictif, non importé'), findsOneWidget);

    await tester.tap(find.text('Réglages').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Comprendre Plano'));
    await tester.tap(find.text('Comprendre Plano'));
    await tester.pumpAndSettle();

    expect(find.text('Que signifie « Inbox » ?'), findsOneWidget);
    expect(find.text('Que signifie « Point client » ?'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(find.text('Ce qui n’est pas encore connecté'), findsOneWidget);
  });
}
