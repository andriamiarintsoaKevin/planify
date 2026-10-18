# Analyse de tâches avec l’IA

L’assistant IA est facultatif. Les tâches ordinaires, leur stockage local et
les autres fonctions de Planify restent disponibles sans compte ni réseau.
L’analyse nécessite une session utilisateur Supabase et une connexion réseau.

## Fonctionnement et données envoyées

Avant le premier envoi, Planify demande le consentement suivant :
« Votre texte est envoyé à Google (Gemini) pour être analysé ». L’accord est
mémorisé localement sur l’appareil et peut être révoqué dans **Réglages >
Assistant IA > Révoquer**.

Après consentement, l’application envoie le texte saisi (maximum 4 000
caractères), le fuseau horaire IANA de l’appareil et la date du jour dans ce
fuseau à la fonction Edge Supabase `dynamic-action`, avec la session de
l’utilisateur connecté. La fonction transmet ces éléments à Google Gemini.
Gemini renvoie des tâches (titre, durée estimée, priorité, notes et éventuelle
date limite). Planify affiche le résultat pour modification et confirmation ;
aucune tâche n’est enregistrée avant **Ajouter à l’Inbox**. Une date limite
reste distincte de l’horaire de planification.

Le texte n’est pas journalisé par l’application. La fonction journalise les
métadonnées d’erreur du fournisseur, pas le contenu de la demande.

## Limite d’utilisation

La limite par défaut est de 10 demandes par utilisateur et par jour. Une
tentative est comptabilisée avant l’appel au fournisseur ; les échecs du
fournisseur libèrent normalement cette réservation. Une limite atteinte
renvoie une erreur HTTP 429 et Planify indique que la limite quotidienne est
atteinte. Si Gemini est temporairement saturé, l’application distingue cette
erreur 429 et invite à réessayer plus tard.

La limite peut être ajustée côté Edge Function avec le secret
`AI_DAILY_LIMIT` (entier de 1 à 1 000). Sans ce secret, la valeur par défaut
reste 10.

## Erreurs affichées

- **Non connecté** : une session est requise ; l’écran propose de se connecter.
- **Hors ligne** : vérifier le réseau et réessayer.
- **429 — limite quotidienne** : réessayer après le renouvellement quotidien.
- **429 — Gemini saturé** : réessayer plus tard.
- **502/503/504** : service temporairement indisponible, inaccessible ou
  délai dépassé ; réessayer plus tard.
- **Réponse invalide** : le résultat ne respecte pas le format attendu ;
  réessayer plus tard.

## Modifier le modèle Gemini

Le modèle est configuré côté Supabase, jamais dans l’application Flutter.
Dans le tableau de bord du projet Supabase `planify-dev`, ouvrez les secrets
des Edge Functions et définissez `GEMINI_MODEL` avec le nom de modèle Gemini
voulu, puis redéployez ou redémarrez la fonction `dynamic-action` si le
changement de secret l’exige. La fonction lit ce secret à chaque exécution
initialisée ; elle utilise `gemini-2.5-flash` comme valeur de secours si le
secret n’est pas défini. La valeur actuellement documentée pour ce projet est
`gemini-3.8-flash`.

Ne placez jamais `GEMINI_API_KEY` dans l’application ou dans ce dépôt : elle
doit rester un secret de la fonction Supabase.
