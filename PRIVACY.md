# Confidentialité

`clm` tourne sur ton PC et n'a aucun serveur. Rien de ce qu'il lit ne part ailleurs que vers ton propre Google Drive.

## Ce que clm fait avec Google Drive

Quand tu connectes un PC, Google demande l'accès `drive.file`. Avec cet accès, `clm` ne voit que les fichiers qu'il a créés lui-même, rangés dans le dossier `clm-sync` de ton Drive. Le reste de ton Drive lui reste invisible.

`clm` y dépose les réglages et les jetons de connexion de tes comptes Claude Code, pour les retrouver sur tes autres PC. Ces fichiers restent dans ton Drive, sous ton compte Google. Personne d'autre n'y a accès, ni l'auteur de `clm`.

Ces fichiers sont chiffrés par ta phrase de synchro avant de partir, jetons compris : Google, ou quelqu'un qui lirait ton Drive, n'en voit que des données illisibles. La phrase elle-même ne quitte jamais tes PC. Restent lisibles les noms des fichiers, leurs dates, le nom de tes PC, la date d'expiration des jetons et l'adresse e-mail de chaque compte. Si tu oublies la phrase, rien ne se récupère : `clm --sync-key-reset` en crée une nouvelle et renvoie les fichiers de ce PC.

## Ce qui reste sur ton PC

Le jeton qui permet à `clm` de parler à ton Drive est rangé dans `drive.json`, dans le dossier de `clm` (`%LOCALAPPDATA%\clm` sous Windows, `~/.local/state/clm` sous Linux, `~/Library/Application Support/clm` sous macOS), sur ton PC seulement. Il n'est jamais envoyé sur le Drive. La phrase de synchro est gardée sous une forme dérivée, protégée par Windows ou par le trousseau de macOS, ou dans un fichier lisible par toi seul sous Linux.

## Couper l'accès

Lance `clm --sync-key-forget` et supprime `drive.json` du dossier de `clm` sur chaque PC, puis retire l'accès de `clm` sur https://myaccount.google.com/permissions. Le dossier `clm-sync` de ton Drive peut ensuite être supprimé à la main.

## Contact

letermeflorent@gmail.com
