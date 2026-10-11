# Planify

Planify est une application Flutter locale en français pour organiser une journée :
capturer des tâches, préparer un planning déterministe, le prévisualiser et le
valider, puis annuler la dernière validation.

## Ce que l’application fait

- Écrans Aujourd’hui, Inbox, Calendrier et Réglages.
- L’Inbox est la boîte des tâches non planifiées ; une tâche quitte l’Inbox
  après validation d’un créneau.
- Création et édition de tâches avec projet, durée, deadline, priorité, notes et
  verrouillage de créneaux déjà planifiés.
- Planification manuelle d’une tâche à une date et une heure choisies. Les
  chevauchements sont autorisés et signalés en rouge ; les tâches terminées
  restent visibles en grisé et ne peuvent plus être modifiées ou supprimées.
- Planification locale sur toute la journée (00 h–24 h), autour des événements
  fixes. La pause déjeuner, la marge entre les tâches et la priorité aux tâches
  urgentes sont des règles facultatives, désactivées par défaut.
- Tri déterministe par deadline, priorité et durée. Les tâches sans durée sont
  estimées à 30 minutes.
- Aperçu du plan, liste des tâches qui ne rentrent pas, validation et annulation
  par snapshot en mémoire.
- Thème clair/sombre.
- Tâches et préférences enregistrées localement dans une base SQLite, conservées
  après fermeture ou redémarrage de l’application jusqu’à leur suppression.

## Ce que l’application ne fait pas encore

- Il n’y a pas de compte utilisateur, de backend, de base de données cloud ni de
  synchronisation entre appareils. Une première installation démarre sans tâche
  ni événement. Les tâches et les réglages sont stockés sur l’appareil dans
  SQLite. La base locale est prise en charge sur Android, iOS, macOS, Windows et
  Linux ; la version Web ne dispose pas de cet adaptateur SQLite.
- Aucun calendrier n’est connecté et aucun rendez-vous fictif n’est ajouté.
- L’import de calendrier, les notifications, les abonnements, les paiements, la
  facturation, les quotas et les fonctions serveur ne sont pas implémentés.
- L’application n’envoie pas les tâches à une IA. Le plan est calculé par le
  moteur local déterministe.

## Organisation du code

- `lib/main.dart` : démarrage, état applicatif et actions principales.
- `lib/ui/screens/` : écrans Aujourd’hui, Inbox, Calendrier, Réglages et guide
  produit.
- `lib/ui/sheets/` : capture/édition de tâche et feuilles de planification.
- `lib/ui/widgets/` : éléments de présentation et résultats des formulaires.
- `lib/ui/theme/` : thème clair et sombre.
- `lib/domain/planner.dart` : modèles de tâches et algorithme déterministe.
- `lib/data/plano_repository.dart` : contrat asynchrone entre l’application et
  ses données.
- `lib/data/sqlite_planify_repository.dart` : stockage local persistant des
  tâches et préférences.
- `lib/data/in_memory_planify_repository.dart` : dépôt temporaire destiné aux
  tests et aux aperçus de l’application.

Les widgets d’interface sont répartis en fichiers `part` de la bibliothèque
`main.dart` afin de garder les implémentations internes privées. Le moteur de
planification reste indépendant de Flutter. L’application reçoit son dépôt par
injection ; un futur adaptateur cloud pourra implémenter le même contrat sans
lier les écrans au SDK d’un fournisseur.

## Exécution et tests

```sh
flutter pub get
flutter run
flutter test
flutter analyze
```

## Intégrations non incluses

La synchronisation calendrier affichée est indicative. Les intégrations SaaS
nécessitent un backend, une configuration de projet, des identifiants et des
règles d’accès par utilisateur qui ne sont pas présents dans ce dépôt.

## Étapes proposées pour une version SaaS

1. Ajouter des contrats dédiés pour l’authentification, les abonnements et les
   snapshots de plan, ainsi que des entités de profil explicites.
2. Choisir et configurer le backend (Firebase était proposé dans le cahier des
   charges initial) : authentification, stockage cloud, règles d’accès par
   utilisateur et gestion des secrets côté serveur.
3. Implémenter les dépôts distants derrière les contrats existants et gérer les
   états de chargement, erreurs, mode hors ligne et synchronisation.
4. Ajouter l’import de calendrier en lecture seule et la replanification avec
   aperçu et historique annulable.
5. Intégrer les abonnements et quotas avec validation des achats côté serveur,
   puis notifications et suivi produit respectueux de la vie privée.
6. Déployer les fonctions serveur, configurer sauvegardes, supervision, sécurité,
   conditions d’utilisation et politique de confidentialité avant une mise en
   production.

La planification doit rester déterministe et testable ; un modèle de langage
pourrait uniquement interpréter une saisie ou expliquer les résultats, après
mise en place d’un service serveur sécurisé.

## Essais manuels

Suivre [TEST_MANUEL_PLANIFY.txt](./TEST_MANUEL_PLANIFY.txt) pour vérifier les
parcours principaux dans l’application.

## License

Copyright (c) 2026 AndriamiarintsoaKevin. All rights reserved.
