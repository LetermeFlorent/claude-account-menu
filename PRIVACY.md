# Confidentialité

`clm` tourne sur ton PC et n'a aucun serveur. Rien de ce qu'il lit ne part ailleurs que vers ton propre Google Drive.

## Ce que clm fait avec Google Drive

Quand tu connectes un PC, Google demande l'accès `drive.file`. Avec cet accès, `clm` ne voit que les fichiers qu'il a créés lui-même, rangés dans le dossier `clm-sync` de ton Drive. Le reste de ton Drive lui reste invisible.

`clm` y dépose les réglages et les jetons de connexion de tes comptes Claude Code, pour les retrouver sur tes autres PC. Ces fichiers restent dans ton Drive, sous ton compte Google. Personne d'autre n'y a accès, ni l'auteur de `clm`.

## Ce qui reste sur ton PC

Le jeton qui permet à `clm` de parler à ton Drive est rangé dans `~/.clm-drive.json`, sur ton PC seulement. Il n'est jamais envoyé sur le Drive.

## Couper l'accès

Supprime `~/.clm-drive.json` sur chaque PC, puis retire l'accès de `clm` sur https://myaccount.google.com/permissions. Le dossier `clm-sync` de ton Drive peut ensuite être supprimé à la main.

## Contact

letermeflorent@gmail.com
