# Vérifications à effectuer sur un vrai appareil Android

Les tests Flutter et l’exécution Linux ne valident pas le comportement spécifique
d’Android. Avant publication, installer l’APK release sur un téléphone Android
réel et vérifier au minimum :

- ouverture de l’application, navigation, export JSON et copie dans le
  presse-papiers ;
- suppression de compte avec réseau : confirmation, résultat de la fonction
  `delete-account`, choix de conservation ou d’effacement local, retour en mode
  local sans session ;
- comportement hors ligne ou en cas d’échec serveur lors de la suppression ;
- effacement local des tâches, réglages et rappels, puis redémarrage de
  l’application ;
- conservation des tâches locales sélectionnée, redémarrage, et absence de
  synchronisation vers l’ancien compte supprimé ;
- permissions Android de notifications et alarmes exactes, ainsi que création,
  déclenchement et annulation des rappels ;
- mise à niveau depuis une version antérieure de l’application, si des données
  existantes doivent être conservées.

Aucun de ces contrôles Android n’est déclaré réussi par les tests Flutter ou
par `flutter run -d linux`.
