# Installer claude-account-menu

Ce guide installe la commande `clm`, de zéro jusqu'au premier lancement, puis explique la migration vers un autre poste, la mise à jour et la désinstallation. Le fonctionnement du menu est décrit dans le [README](README.md).

## Avant de commencer sous Windows

Il faut Windows 10 version 1803 ou plus récente, car la sauvegarde s'appuie sur le `tar.exe` livré avec Windows. Le menu tourne toujours sous Windows PowerShell 5.1, présent sur ces versions, même quand PowerShell 7 est installé à côté. Claude Code doit être installé et avoir été lancé au moins une fois avec `claude`, pour que le premier compte soit connecté. Git sert à récupérer le dépôt. Sans Git, le bouton "Code" puis "Download ZIP" de la page GitHub donne la même chose, le dépôt étant public.

Pour vérifier les prérequis dans un terminal :

```powershell
$PSVersionTable.PSVersion.Major
Test-Path "$env:SystemRoot\System32\tar.exe"
claude --version
```

La première commande doit afficher 5 ou plus, la deuxième `True`, la troisième un numéro de version.

## Installation sous Windows

Récupérer le dépôt puis lancer l'installeur :

```powershell
git clone https://github.com/LetermeFlorent/claude-account-menu.git
cd claude-account-menu
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

L'installeur copie les fichiers `.ps1` et `.cmd` du dossier `bin` dans `%USERPROFILE%\.local\bin`, en écrasant les anciennes versions, et ajoute ce dossier au PATH de l'utilisateur quand il n'y est pas déjà. Il prévient si `tar.exe` ou Claude Code manquent, sans s'arrêter.

Il ajoute ensuite un hook `SessionStart` dans le `settings.json` de `.claude` et de chaque dossier `.claude-compte*` du dossier personnel qui en a un. À chaque démarrage de Claude Code, ce hook écrit les quotas 5 h et 7 j du compte dans le fichier d'état de la [barre d'état](https://github.com/LetermeFlorent/claude-statusline), avec cette commande :

```
powershell -NoProfile -ExecutionPolicy Bypass -File "C:/Users/<utilisateur>/.local/bin/claude-statusline-seed.ps1"
```

Un `settings.json` qui contient déjà le hook n'est pas touché, donc une seconde installation n'ajoute rien en double. Les autres reçoivent d'abord une copie `settings.json.bak-seed`, puis sont réécrits par PowerShell : les valeurs restent les mêmes, la mise en forme change. Un `settings.json` qui n'est pas du JSON valide arrête l'installeur à cet endroit, une fois les scripts copiés : le corriger puis relancer. Aucun autre fichier de compte n'est modifié.

Le PATH n'est relu qu'à l'ouverture d'un terminal : fermer la fenêtre et en ouvrir une nouvelle avant de taper `clm`.

## Installation sous Linux et macOS

Il faut PowerShell 7, dont la commande est `pwsh`. Sous macOS, `brew install powershell` suffit. Sous Linux, la documentation de Microsoft donne la méthode pour chaque distribution : https://learn.microsoft.com/powershell/scripting/install/linux-overview. Claude Code doit être installé et connecté au moins une fois, comme sous Windows.

```sh
git clone https://github.com/LetermeFlorent/claude-account-menu.git
cd claude-account-menu
sh install.sh
```

`install.sh` copie les fichiers `.ps1` et le lanceur `clm` dans `~/.local/bin` et rend `clm` exécutable. Si ce dossier manque au PATH, il affiche la ligne `export PATH=...` à mettre dans `~/.profile`, `~/.bashrc` ou `~/.zshrc`. Il prévient si Claude Code est introuvable. Il ajoute enfin le même hook que sous Windows, lancé cette fois par `pwsh -NoProfile -File`, avec les mêmes règles.

Sans `pwsh`, `install.sh` copie les fichiers, indique quoi installer et s'arrête avec le code 1 avant le hook : le relancer une fois PowerShell 7 en place. Le lanceur `clm` vérifie lui aussi la présence de `pwsh`, et sans elle affiche les liens d'installation et sort avec le code 127.

Sous Linux, la sauvegarde passe par `bsdtar` s'il est présent (paquet `libarchive-tools` sur Debian et Ubuntu) et produit un `.zip` lisible sur les autres postes. Sinon GNU tar écrit un `.tar.gz`, et un `.zip` venu de Windows ou de macOS ne peut pas être restauré. `install.sh` le signale quand `bsdtar` manque.

Sous macOS, Claude Code range les jetons dans le trousseau, où le menu les lit avec la commande `security`. Au premier accès, macOS peut demander d'autoriser cette lecture.

## Premier lancement

Au premier lancement, quand `.claude-accounts.json` n'existe pas encore dans le dossier personnel, `clm` crée la liste des comptes : `.claude` devient `compte1`, puis chaque dossier présent de `.claude-compte2` à `.claude-compte9` devient un compte du même nom. Ensuite, seule cette liste compte. Un dossier de compte nommé autrement, ou créé à la main après coup, doit y être ajouté à la main, au format décrit dans le README.

Sur un poste qui n'a qu'un seul compte, le menu n'en montre donc qu'un. Appuyer sur `a` pour en ajouter : le menu demande un nom, crée le dossier, puis ouvre la connexion dans le navigateur. Si claude.ai est déjà connecté sur un autre compte dans ce navigateur, copier le lien de connexion dans une fenêtre privée, sinon c'est l'autre compte qui sera enregistré. La touche `x` fait l'inverse : elle retire un compte du menu, et peut aussi effacer son dossier après en avoir rangé une archive dans Téléchargements.

Pour vérifier que tout répond sans ouvrir le menu :

```sh
clm --usage
```

La commande affiche une ligne par compte avec son adresse, son abonnement et ses quotas.

## Migrer vers un autre poste

Sur l'ancien poste, appuyer sur `s` dans le menu : tous les comptes sont déjà cochés, Entrée lance la sauvegarde. L'archive arrive dans le dossier Téléchargements, sous le nom `claude-comptes-<date>-<heure>`.

Sur le nouveau poste, installer `clm` comme ci-dessus et copier l'archive dans le dossier Téléchargements. Appuyer sur `r`, qui liste les neuf sauvegardes les plus récentes de ce dossier, choisir l'archive par son numéro, cocher les comptes voulus, valider par Entrée puis confirmer par `o`. Une archive gardée ailleurs se restaure avec `clm --restore=<chemin>`. Les comptes absents du nouveau poste sont ajoutés au menu sous le nom qu'ils avaient, et les dossiers partagés sont reliés à `.claude`.

Une archive faite sous Windows ou Linux contient les jetons de connexion : restaurés sur Windows ou Linux, les comptes sont utilisables tout de suite, sans nouvelle connexion. Une archive faite sous macOS n'en contient pas, puisqu'ils restent dans le trousseau, et le menu n'écrit jamais dans le trousseau : chaque compte restauré depuis une telle archive se reconnecte une fois, en le lançant puis en tapant `/login`.

L'archive n'est pas chiffrée et contient les jetons en clair. La transférer par un moyen sûr, puis la supprimer des deux postes dès que la migration est faite, avec les copies `claude-comptes-avant-restauration-*` que la restauration laisse aussi dans Téléchargements.

## Mettre à jour

Récupérer la dernière version avec `git pull` dans le dossier cloné, puis relancer `install.ps1`, ou `install.sh` sous Linux et macOS. Les comptes, leurs jetons et `.claude-accounts.json` ne sont pas modifiés, et le hook déjà en place n'est pas ajouté une seconde fois.

Claude Code lui-même est mis à jour par `clm`, avec `claude update`, à chaque ouverture du menu et à chaque lancement direct comme `clm -2`. Pour sauter cette étape une fois, lancer `clm --no-update`.

## Désinstaller

La désinstallation se fait à la main, en quatre étapes :

1. Retirer du `settings.json` de chaque compte l'entrée `SessionStart` qui mentionne `claude-statusline-seed.ps1`. Remettre `settings.json.bak-seed` à la place marche aussi, mais perd les réglages changés depuis l'installation. Supprimer ensuite les fichiers `settings.json.bak-seed`.
2. Supprimer de `%USERPROFILE%\.local\bin`, ou de `~/.local/bin`, les fichiers `clm`, `clm.cmd`, `claude-menu.cmd` et `claude-*.ps1`, sans toucher à `claude.exe` ni à `claude`, qui sont Claude Code. Sous Windows, l'installeur a ajouté ce dossier au PATH de l'utilisateur : l'en retirer seulement si plus rien n'y vit, Claude Code s'y installant aussi.
3. Supprimer le cache des quotas : `%LOCALAPPDATA%\claude-menu` sous Windows, `~/Library/Caches/claude-menu` sous macOS, `${XDG_CACHE_HOME:-~/.cache}/claude-menu` sous Linux.
4. Supprimer `.claude-accounts.json` du dossier personnel, la liste des comptes propre au menu, et les archives `claude-comptes-*` du dossier Téléchargements, qui contiennent des jetons.

Les dossiers de comptes (`.claude`, `.claude-compte2`, etc.) restent en place : ils appartiennent à Claude Code, qui continue de les utiliser avec `CLAUDE_CONFIG_DIR`. Les clés écrites dans le fichier d'état de la barre d'état restent aussi, sans effet une fois périmées.

## En cas de problème

Si `clm` n'est pas reconnu, le terminal a été ouvert avant l'installation. En ouvrir un nouveau, ou lancer directement `%USERPROFILE%\.local\bin\clm.cmd`.

Si la mise à jour affiche "verification impossible", `claude update` n'a rien annoncé en 20 secondes, souvent faute de réseau : le menu s'ouvre quand même avec la version installée. "telechargement bloque" signale un téléchargement figé pendant 90 secondes, et "deja en cours ailleurs" une autre session qui met déjà Claude Code à jour. `clm --no-update` ouvre le menu sans attendre.

Si un compte affiche "jeton refuse" ou "jeton a rafraichir", lancer ce compte une fois avec son numéro (`clm -2` par exemple) : Claude Code renouvelle le jeton au démarrage. "non connecte" veut dire qu'aucun jeton n'a été trouvé : lancer le compte et taper `/login`.

Si un compte affiche "quota inconnu", l'API de suivi limite ses appels et aucune valeur récente n'est en cache. Attendre le délai indiqué puis rouvrir le menu. Quand le cache a des valeurs, le menu les affiche avec la mention "valeurs lues il y a".

`clm -N` répond "pas de compte N" quand ce numéro n'existe pas, et `--save=` ou `--only=` répondent "compte inconnu : ..." pour un nom absent de la liste. Les noms attendus sont ceux affichés dans le menu, pas ceux des dossiers.

Si la sauvegarde signale des avertissements, ou si la restauration annonce des fichiers non restaurés, une session Claude Code est probablement ouverte sur ce compte et garde des fichiers verrouillés. La fermer et recommencer.

Sous Linux, "GNU tar ne lit pas les zip" demande d'installer `bsdtar` (paquet `libarchive-tools`) pour restaurer un `.zip` venu d'un autre poste.

Si la barre d'état n'a pas ses quotas au lancement d'un compte avec `claude`, vérifier que le `settings.json` de ce compte contient le hook, et que son dossier figure dans `.claude-accounts.json` : le hook ne fait rien pour un dossier absent de la liste.
