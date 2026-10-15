# Planify

Planify est une application Flutter locale en français pour organiser une journée :
capturer des tâches, préparer un planning déterministe, le prévisualiser et le
valider, puis annuler la dernière validation.

## Ce que l’application fait

- Écrans Aujourd’hui, Inbox, Calendrier et Réglages.
- L’Inbox est la boîte des tâches non planifiées ; une tâche quitte l’Inbox
  après validation d’un créneau.
- Création et édition de tâches avec projet, durée de 15 minutes à 4 heures,
  priorité, notes, rappel local facultatif et verrouillage des créneaux.
  La fin planifiée est calculée depuis le début et la durée ; la date limite
  reste une propriété distincte et facultative.
- Les tâches sont différenciées par priorité : basse en vert, normale en indigo
  et haute en rouge, avec des teintes adaptées au thème clair ou sombre.
- Planification manuelle d’une tâche à une date et une heure choisies, ainsi
  que déplacement par glisser-déposer des tâches non verrouillées dans le
  calendrier sans modifier leur durée. Les
  chevauchements sont autorisés et signalés en rouge ; les tâches terminées
  restent visibles en grisé et ne peuvent plus être modifiées ou supprimées.
- Planification locale des tâches de l’Inbox sans horaire, à partir de l’heure
  actuelle lorsqu’on planifie aujourd’hui et autour des horaires déjà fixés.
  La pause déjeuner, la marge entre les tâches et la priorité aux tâches
  urgentes sont des règles facultatives, désactivées par défaut.
- Tri déterministe par date limite, priorité et durée. Les tâches sans durée sont
  estimées à 30 minutes.
- Aperçu du plan, liste des tâches qui ne rentrent pas, validation et annulation
  par snapshot en mémoire.
- Thème clair/sombre avec champs, panneaux, navigation et contrastes adaptés.
- Tâches et préférences enregistrées localement dans une base SQLite, conservées
  après fermeture ou redémarrage de l’application jusqu’à leur suppression.

## Ce que l’application ne fait pas encore

- Il n’y a pas de compte utilisateur, de backend, de base de données cloud ni de
  synchronisation entre appareils. Une première installation démarre sans tâche
  ni événement. Les tâches et les réglages sont stockés sur l’appareil dans
  SQLite. La base locale est prise en charge sur Android, iOS, macOS, Windows et
  Linux ; la version Web ne dispose pas de cet adaptateur SQLite.
- Les calendriers présents sur l’appareil peuvent être connectés en lecture
  seule sur Android et iOS. Un calendrier Google doit d’abord être synchronisé
  dans les réglages système de l’appareil. Planify ne modifie aucun événement.
- Les rappels locaux des tâches planifiées sont facultatifs et demandent
  l’autorisation du système. Les abonnements, paiements, facturation, quotas et
  fonctions serveur ne sont pas implémentés.
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
  ses préférences et événements.
- `lib/data/task_repository.dart` : contrat asynchrone de gestion des tâches.
- `lib/data/sqlite_planify_repository.dart` : implémentation SQLite des tâches
  et préférences, avec suppression logique.
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

Supabase peut être configuré au lancement sans fichier de secrets embarqué :
copiez `env.example.json` dans le fichier local ignoré `env.dev.json`, puis
renseignez l’URL et la clé publique `anon` du projet. Pour lancer l’application
avec cette configuration :

```sh
flutter run --dart-define-from-file=env.dev.json
```

Sans ces définitions, l’application conserve son mode local SQLite.

## Compatibilité et distribution Android

Planify est compatible avec Android 7.0 (API 24) et les versions ultérieures.
Cette limite vient des plugins de rappels et de calendrier utilisés par
l’application ; les versions antérieures ne peuvent donc pas être prises en
charge sans retirer ces fonctions. L’identifiant Android actuel est
`com.example.planify` : il n’est pas lié à l’appareil de test, mais doit être
remplacé par un identifiant unique avant une publication publique.

`flutter run` installe une version de développement ; pour transmettre une
version plus légère, générez un APK de production distinct pour chaque
architecture :

```sh
flutter build apk --release --split-per-abi
```

Les fichiers sont créés dans `build/app/outputs/flutter-apk/`. Transmettez
celui qui correspond au processeur de l’appareil :

- `app-arm64-v8a-release.apk` pour la plupart des téléphones récents ;
- `app-armeabi-v7a-release.apk` pour les appareils Android 32 bits ;
- `app-x86_64-release.apk` pour les appareils x86_64, notamment certains
  émulateurs.

Pour une distribution par Google Play, générez plutôt un bundle :

```sh
flutter build appbundle --release
```

La configuration Gradle actuelle signe encore les versions `release` avec la
clé de débogage : ces APK conviennent aux essais et au transfert direct, mais
pas à une publication sur Google Play ni à des mises à jour de production.
Avant publication, configurez une clé de signature privée et conservez-la
durablement ; les mises à jour doivent garder la même clé et le même
identifiant d’application.

Enfin, le transfert de l’APK ne transfère pas les tâches ni les réglages :
ceux-ci sont enregistrés dans une base SQLite sur chaque appareil. Planify
n’inclut actuellement ni export/import ni synchronisation entre appareils.

## Intégrations non incluses

La connexion calendrier lit les calendriers fournis par le système mobile et
ne nécessite pas d’identifiants OAuth Planify. Elle ne synchronise pas les
tâches entre appareils.

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
