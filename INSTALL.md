# Installer claude-account-menu

Ce guide installe la commande `clm` sur un poste Windows, de zéro jusqu'au premier lancement.

## Avant de commencer

Il faut Windows 10 version 1803 ou plus récente, car la sauvegarde s'appuie sur le `tar.exe` livré avec Windows. PowerShell 5.1 est déjà présent sur ces versions. Claude Code doit être installé et avoir été lancé au moins une fois avec `claude`, de sorte que le premier compte soit connecté. Git sert à récupérer le dépôt, mais on peut s'en passer en téléchargeant l'archive ZIP depuis la page GitHub, une fois connecté (le dépôt est privé).

Pour vérifier les prérequis dans un terminal :

```powershell
$PSVersionTable.PSVersion.Major
Test-Path "$env:SystemRoot\System32\tar.exe"
claude --version
```

La première commande doit afficher 5 ou plus, la deuxième `True`, la troisième un numéro de version.

## Installation

Récupérer le dépôt puis lancer l'installeur :

```powershell
git clone https://github.com/LetermeFlorent/claude-account-menu.git
cd claude-account-menu
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

L'installeur copie les scripts du dossier `bin` dans `%USERPROFILE%\.local\bin`, écrase les anciennes versions s'il y en a, et ajoute ce dossier au PATH de l'utilisateur quand il n'y est pas déjà. Il prévient si `tar.exe` ou Claude Code manquent. Il ajoute aussi, dans le `settings.json` de `.claude` et de chaque `.claude-compte*`, un hook `SessionStart` qui lance `claude-statusline-seed.ps1` : à chaque démarrage de Claude Code, les quotas 5 h et 7 j du compte courant sont écrits dans le fichier d'état de la barre d'état. Une copie `settings.json.bak-seed` est gardée avant la modification, et une seconde exécution de l'installeur n'ajoute rien en double. Aucun autre fichier de compte n'est touché.

Le PATH n'est relu qu'à l'ouverture d'un terminal : fermer la fenêtre et en ouvrir une nouvelle avant de taper `clm`.

## Premier lancement

`clm` lit les dossiers de configuration déjà présents : `.claude` devient le compte 1, et chaque dossier `.claude-compte2`, `.claude-compte3` et suivants devient un compte supplémentaire. La liste est écrite dans `%USERPROFILE%\.claude-accounts.json` à la première exécution.

Sur un poste qui n'a qu'un seul compte, le menu n'en montre donc qu'un. Appuyer sur `a` pour en ajouter : le menu demande un nom, crée le dossier, puis ouvre la connexion dans le navigateur. Si claude.ai est déjà connecté sur un autre compte dans ce navigateur, copier le lien de connexion dans une fenêtre privée, sinon c'est l'autre compte qui sera enregistré.

Pour vérifier que tout répond sans ouvrir le menu :

```powershell
clm --usage
```

La commande affiche une ligne par compte avec son adresse, son abonnement et ses quotas.

## Migrer vers un autre poste

Sur l'ancien poste, appuyer sur `s` dans le menu, cocher tous les comptes, valider. Le zip arrive dans le dossier Téléchargements. Sur le nouveau poste, installer comme ci-dessus, copier le zip dans son dossier Téléchargements, puis appuyer sur `r`, choisir le zip et les comptes à restaurer. Les jetons de connexion sont dans le zip, donc les comptes sont directement utilisables, sans nouvelle connexion dans le navigateur.

Le zip contient ces jetons en clair. Le transférer par un moyen sûr et le supprimer des deux postes dès que la migration est faite.

## Mettre à jour

Récupérer la dernière version avec `git pull` dans le dossier cloné, puis relancer `install.ps1`. Les comptes, leurs jetons et le fichier `.claude-accounts.json` ne sont pas modifiés.

## Désinstaller

Retirer l'entrée `SessionStart` qui mentionne `claude-statusline-seed.ps1` du `settings.json` de chaque compte (ou remettre `settings.json.bak-seed`). Supprimer de `%USERPROFILE%\.local\bin` les fichiers `clm.cmd`, `claude-menu.cmd`, `claude-menu*.ps1`, `claude-usage*.ps1`, `claude-statusline-seed.ps1` et `claude-accounts.ps1`. Supprimer ensuite le cache des quotas dans `%LOCALAPPDATA%\claude-menu`. Les dossiers de comptes et `.claude-accounts.json` restent en place : ils appartiennent à Claude Code, pas au menu.

## En cas de problème

Si `clm` n'est pas reconnu, le terminal a été ouvert avant l'installation. En ouvrir un nouveau, ou lancer directement `%USERPROFILE%\.local\bin\clm.cmd`.

Si un compte affiche "jeton refuse" ou "jeton a rafraichir", lancer ce compte une fois avec son numéro (`clm -2` par exemple) : Claude Code renouvelle le jeton au démarrage.

Si les quotas affichent "quota inconnu", l'API de suivi limite ses appels. Attendre le délai indiqué et rouvrir le menu, ou lire les dernières valeurs gardées en cache, signalées par "valeurs lues il y a".

Si la sauvegarde signale des avertissements, ou si la restauration ignore des fichiers, une session Claude Code est probablement ouverte sur ce compte et garde des fichiers verrouillés. La fermer et recommencer.
