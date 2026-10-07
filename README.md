# claude-account-menu

Menu en terminal pour jongler entre plusieurs comptes Claude Code sur un même poste, sous Windows, Linux ou macOS. Chaque compte vit dans son propre dossier de configuration (`.claude`, `.claude-compte2`, etc.), et `clm` lance Claude Code sur celui qu'on choisit, avec le quota 5 h et 7 j de chacun affiché à côté.

## Installation

Le guide complet, avec la vérification, la mise à jour et la désinstallation, est dans [INSTALL.md](INSTALL.md). Version courte pour Windows, qui demande Windows 10 1803 ou plus récent (pour `tar.exe`), PowerShell 5.1 ou 7, et Claude Code déjà installé :

```powershell
git clone https://github.com/LetermeFlorent/claude-account-menu.git
cd claude-account-menu
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Le script copie les fichiers de `bin` dans `%USERPROFILE%\.local\bin` et ajoute ce dossier au PATH utilisateur si besoin. Ouvrir ensuite un nouveau terminal et taper `clm`.

Sous Linux et macOS, le menu tourne sur PowerShell 7 (`pwsh`). Une fois `pwsh` installé :

```sh
git clone https://github.com/LetermeFlorent/claude-account-menu.git
cd claude-account-menu
sh install.sh
```

Les scripts arrivent dans `~/.local/bin`, avec le lanceur `clm`. L'installeur indique la ligne à ajouter au profil du shell si ce dossier manque au PATH.

## Touches du menu

Les flèches et Entrée lancent le compte sélectionné, les chiffres 1 à 9 lancent directement le compte correspondant. Le reste :

- `a` ajoute un compte : nom, création du dossier, puis connexion dans le navigateur
- `s` sauvegarde les comptes cochés dans le dossier Téléchargements
- `r` restaure tout ou partie d'une sauvegarde
- `q` ou Échap quitte

À l'ajout d'un compte, si claude.ai est déjà connecté dans le navigateur sur un autre compte, c'est cet autre compte qui sera enregistré. Ouvrir le lien de connexion dans une fenêtre privée évite le piège.

## Ligne de commande

```
clm -2                       lance le compte 2
clm -2 --resume              les arguments restants passent à Claude Code
clm --no-update              ouvre le menu sans chercher de mise à jour de Claude Code
clm --usage                  quotas de tous les comptes
clm --save                   sauvegarde complète
clm --save=compte2,compte3   sauvegarde de certains comptes
clm --restore=<fichier> --only=compte2
```

## Mise à jour de Claude Code

Avant d'afficher le menu, et avant un lancement direct comme `clm -2`, `clm` lance `claude update` une fois par exécutable de Claude Code, avec l'environnement du premier compte qui l'utilise. Une barre suit le téléchargement : pourcentage et mégaoctets quand la taille attendue est connue, mégaoctets seuls sinon. Pour une installation par npm, la barre laisse place à un témoin d'attente et à la dernière ligne affichée par `claude update`. Le résultat s'affiche pour chaque compte pendant l'étape, puis reste sous le menu.

Sans réponse au bout de 20 secondes, la vérification est abandonnée. Un téléchargement n'est interrompu que si sa taille n'a pas bougé depuis 90 secondes, et jamais une fois le fichier complet. `--usage`, `--save` et `--restore` sautent cette étape, `--no-update` aussi.

## Ce que contient une sauvegarde

L'archive reprend l'arborescence du dossier utilisateur : le dossier de chaque compte coché (jetons, réglages, skills, plugins, MCP, historique des conversations), `.claude.json` et `.mcp.json` avec le premier compte, la liste des comptes et les scripts du menu. Les caches et fichiers de session sont exclus.

C'est un `.zip` sous Windows et macOS, et sous Linux quand `bsdtar` est installé (paquet `libarchive-tools`). Avec le seul GNU tar, Linux écrit un `.tar.gz` et ne sait pas relire un `.zip` venu d'un autre poste.

Les comptes secondaires partagent les dossiers `agents`, `commands`, `hooks`, `rules` et `skills` du premier compte, par des jonctions sous Windows et des liens symboliques ailleurs, et quelques fichiers (`CLAUDE.md`, `settings.local.json`, `statusline.json`) par des liens physiques. Ces éléments partagés ne sont sauvegardés qu'une fois, avec le premier compte, et les liens sont recréés à la restauration.

Avant toute restauration, l'état actuel des comptes visés est copié dans une archive `claude-comptes-avant-restauration-*`.

L'archive n'est pas chiffrée et contient les jetons de connexion : quiconque la récupère peut se servir des comptes.

## Quotas et rythme

Les pourcentages viennent de l'API `api.anthropic.com/api/oauth/usage`, qui limite elle-même le nombre d'appels. Sous macOS, les jetons sont lus dans le trousseau, où Claude Code les range. Les résultats sont gardés deux minutes dans un cache, et le menu affiche les dernières valeurs connues quand l'API refuse. Le cache est dans `%LOCALAPPDATA%\claude-menu\usage.json` sous Windows, `~/Library/Caches/claude-menu/usage.json` sous macOS et `${XDG_CACHE_HOME:-~/.cache}/claude-menu/usage.json` sous Linux.

À côté de chaque barre, un verdict compare la consommation au temps écoulé dans la fenêtre. Le pourcentage est projeté jusqu'à la fin de la fenêtre : sous 70 %, le compte est "large", jusqu'à 100 % il va à "bon rythme", jusqu'à 130 % il est "agressif", au-delà c'est "trop", avec l'heure à laquelle le quota serait épuisé. Pour "agressif" et "trop", le verdict donne aussi le rythme à ne pas dépasser jusqu'au reset, en points par heure pour 5 h et par jour pour 7 j. Avant 10 % de la fenêtre, il affiche "trop tot". Quand la ligne ne tient pas dans la largeur du menu, les verdicts passent sur une seconde ligne. `clm --usage` les ajoute en fin de chaque quota.

## Couleurs claires ou sombres

Le menu choisit sa palette dans cet ordre : la variable `STATUSLINE_BG` (`light`, `clair`, `dark` ou `sombre`), puis `terminal_background` dans `~/.claude/statusline.json` quand il vaut `light` ou `dark`, puis la réponse de `~/.claude/bin/statusline --theme` si ce binaire est présent, puis le thème du système. Sous Windows c'est le réglage des applications, sous macOS l'apparence, sous Linux `gsettings`, `GTK_THEME` ou les couleurs de KDE. À défaut, la palette sombre s'applique.

## Barre d'état à jour au lancement

Quand `clm` lance un compte, il écrit d'abord les quotas 5 h et 7 j de ce compte dans le fichier d'état de la barre d'état, de sorte que les valeurs sont justes dès le premier affichage. Ce fichier est `%LOCALAPPDATA%\claude-statusline\state` sous Windows, `~/Library/Application Support/claude-statusline/state` sous macOS et `${XDG_STATE_HOME:-~/.local/state}/claude-statusline/state` sous Linux. Chaque compte y a ses propres clés (`q5_pct@claude-compte2` par exemple), et le script n'écrit que celles du compte lancé. Pour le même effet avec un simple `claude`, l'installeur ajoute un hook `SessionStart` dans le `settings.json` de chaque compte. Si le compte n'a aucune fenêtre de 5 h ouverte, la barre garde `--%` sur 5 h jusqu'au premier message.

## Tests

`tests/run.ps1` vérifie les fonctions sans réseau ni vrai compte, dans un dossier temporaire, et sort avec un code non nul en cas d'échec. Il tourne avec `powershell -File tests\run.ps1` comme avec `pwsh -File tests/run.ps1`. Le calcul du suffixe de compte du fichier d'état a en plus un test Pester, `tests/StateTag.Tests.ps1`.
