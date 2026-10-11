# Planify

Planify est un prototype Flutter en français pour organiser une journée de
travail : capturer des tâches, préparer un planning déterministe, le prévisualiser
et le valider, puis annuler la dernière validation.

## Fonctionnalités du MVP

- Écrans Aujourd’hui, Inbox, Calendrier et Réglages.
- Création et édition de tâches avec projet, durée, deadline, priorité, notes et
  verrouillage de créneaux déjà planifiés.
- Planification locale autour des événements fixes, de la pause déjeuner et
  d’une marge configurable.
- Tri déterministe par deadline, priorité et durée. Les tâches sans durée sont
  estimées à 30 minutes.
- Aperçu du plan, liste des tâches qui ne rentrent pas, validation et annulation
  par snapshot en mémoire.
- Thème clair/sombre et horaires de travail modifiables.

L’application démarre avec des tâches et un événement de démonstration. Les
données restent en mémoire et sont réinitialisées au redémarrage.

## Organisation du code

- `lib/main.dart` : démarrage, état de démonstration et actions applicatives.
- `lib/today_screen.dart`, `lib/inbox_screen.dart`, `lib/calendar_screen.dart`
  et `lib/settings_screen.dart` : UI par onglet.
- `lib/task_editor.dart` : capture rapide et formulaire de tâche.
- `lib/planner_sheets.dart` : réglages et aperçu du plan.
- `lib/ui_helpers.dart` : éléments de présentation et résultats des formulaires.
- `lib/app_theme.dart` : thème clair et sombre.
- `lib/planner.dart` : modèles de tâches et algorithme déterministe.

Les widgets d’interface sont répartis en fichiers `part` de la bibliothèque
`main.dart` afin de garder les implémentations internes privées. Le moteur de
planification reste indépendant de Flutter.

## Exécution et tests

```sh
flutter pub get
flutter run
flutter test
flutter analyze
```

## Intégrations non incluses

La synchronisation calendrier affichée est indicative. Ces intégrations
nécessitent des configurations de projet et identifiants spécifiques qui ne
sont pas présents dans ce dépôt. Le moteur de planification est du Dart pur et
ne fait aucun appel à un LLM.

## License

Copyright (c) 2026 AndriamiarintsoaKevin. All rights reserved.
