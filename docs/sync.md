# Synchronisation des tâches

La synchronisation est facultative. Les tâches restent enregistrées dans
SQLite et l'application reste utilisable sans compte ou sans réseau. Après
connexion, `TaskRepository` ajoute chaque changement à `sync_queue` dans la
même transaction que la modification locale.

## Règle de conflit

Une tâche distante n'est appliquée que si son `updated_at` est strictement plus
récent que celui de la copie locale. À horodatage égal, la copie locale est
conservée. Une suppression logique (`deleted_at` non nul) est prioritaire sur
toute version active, quel que soit son horodatage. Cette règle est appliquée
au merge local et par le trigger SQL de la migration
`20261015180000_enforce_task_sync_conflicts.sql`, ce qui empêche un upsert
ancien de ressusciter une tâche supprimée ou de remplacer une version plus
récente.

## Envoi et réception

Les opérations de la file sont envoyées par identifiant croissant, avec un
upsert sur l'UUID de la tâche. Une suppression envoie le tombstone `deleted_at`
et non une commande SQL DELETE. Après échec, une opération est retentée après
2, 4, 8, 16 puis 32 secondes (plafond de 30 minutes) ; après cinq échecs, elle
reste en état `error` jusqu'à une reprise explicite. L'erreur stockée est le
type d'exception et ne contient pas le contenu de la tâche.

Les changements distants sont lus par pages avec un curseur composé
`(updated_at, id)`, limités à un instant de fin fixe pour la passe. Cette
pagination par clé évite les décalages qu'un offset causerait si une ligne
changeait pendant le téléchargement. Le curseur `task_sync_cursor` n'est avancé
qu'après réception et merge de toutes les pages. RLS limite ces lectures et
écritures au compte connecté.

## États affichés

- **À jour** : aucune opération locale en attente.
- **En attente** : des opérations attendent leur envoi.
- **Erreur** : la dernière synchronisation a échoué ou une opération a atteint
  sa limite de tentatives ; « Réessayer » remet en attente les opérations en
  erreur.
- **Hors ligne** : aucun réseau détecté ou aucun compte connecté. Les données
  locales restent disponibles.

## Vérification manuelle sur deux appareils

1. Configurez la même URL Supabase et la même clé publique sur les deux
   appareils, appliquez les migrations et connectez-les au même compte.
2. Sur A, créez une tâche en mode avion, puis réactivez le réseau et attendez
   l'état **À jour**.
3. Sur B, déclenchez **Actualiser** ou attendez le cycle de synchronisation :
   la tâche doit apparaître une seule fois.
4. Modifiez la tâche sur A puis B avec le réseau ; vérifiez qu'après la
   synchronisation, la version avec le `updated_at` le plus récent est visible
   sur les deux appareils.
5. Supprimez la tâche sur A, attendez **À jour**, puis vérifiez qu'elle reste
   absente sur B après actualisation.
