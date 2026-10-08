# claude-account-menu

Menu en terminal pour jongler entre plusieurs comptes Claude Code sur un même poste, sous Windows, Linux ou macOS. Chaque compte vit dans son propre dossier de configuration (`.claude`, `.claude-compte2`, etc.), et `clm` lance Claude Code sur celui qu'on choisit, avec le quota 5 h et 7 j de chacun affiché à côté. Il sert aussi à ajouter, retirer, sauvegarder et restaurer des comptes, et met Claude Code à jour avant chaque lancement.

## Installation

Le guide complet, avec la vérification, la mise à jour et la désinstallation, est dans [INSTALL.md](INSTALL.md). Sous Windows, il faut Windows 10 1803 ou plus récent (pour `tar.exe`) et Claude Code déjà installé. Le menu y tourne sous Windows PowerShell 5.1, livré avec le système.

```powershell
git clone https://github.com/LetermeFlorent/claude-account-menu.git
cd claude-account-menu
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Le script copie les fichiers `.ps1` et `.cmd` de `bin` dans `%USERPROFILE%\.local\bin` et ajoute ce dossier au PATH utilisateur si besoin. Ouvrir ensuite un nouveau terminal et taper `clm`.

Sous Linux et macOS, le menu tourne sur PowerShell 7 (`pwsh`). Une fois `pwsh` installé :

```sh
git clone https://github.com/LetermeFlorent/claude-account-menu.git
cd claude-account-menu
sh install.sh
```

Les scripts `.ps1` et le lanceur `clm` arrivent dans `~/.local/bin`. L'installeur indique la ligne à ajouter au profil du shell si ce dossier manque au PATH.

Les deux installeurs ajoutent aussi un hook `SessionStart` aux comptes existants, décrit plus bas dans "Barre d'état à jour au lancement".

## Le menu

Au démarrage, `clm` met d'abord Claude Code à jour (voir plus bas), affiche "Chargement usage...", puis le menu. L'en-tête "Comptes Claude Code" porte l'heure du dernier affichage. Chaque compte occupe un bloc :

- une ligne avec son numéro, son nom, l'adresse e-mail du compte, et à droite son abonnement (`Max 20x`, `Max 5x`, `Pro`, etc.), précédé d'un badge rouge "quota 7d atteint" ou "quota 5h atteint" quand un quota est à 100 % ;
- une ligne avec les barres 5 h et 7 j : 8 cases, le pourcentage, le temps avant remise à zéro (`2h05m`, `3j4h`, `0m`, ou `-` s'il est inconnu) et le mot qui résume le rythme d'utilisation ;
- à la place des barres, un message d'erreur en rouge quand les quotas ne sont pas lisibles ;
- "valeurs lues il y a ..." quand les chiffres viennent du cache depuis plus d'une minute, ou "fenetre passee depuis la derniere lecture il y a ..." quand une remise à zéro a eu lieu depuis.

Les barres changent de teinte à 30 % puis à 70 %, comme la barre d'état : violet, mauve et rouge framboise pour le 5 h, vert, ocre et rouge pour le 7 j. Leur dégradé reprend `gradient.5h` et `gradient.7d` de `~/.claude/statusline.json` s'ils y sont. Le menu fait 78 colonnes de large.

Le curseur part sur le premier compte lisible dont aucun quota n'est à 100 %, à défaut sur le premier. Les quotas ne se rafraîchissent pas seuls : ils sont relus après chaque ajout, retrait, sauvegarde ou restauration.

### Touches

Le pied du menu rappelle les touches principales :

| Touche | Action |
|---|---|
| flèches haut et bas | déplacer le curseur, en boucle |
| Entrée | lancer le compte sélectionné |
| `1` à `9` | lancer directement le compte de ce numéro |
| `a` | ajouter un compte |
| `x` | retirer un compte |
| `s` | sauvegarder des comptes |
| `r` | restaurer une sauvegarde |
| `q` ou Échap | quitter |

Les lettres marchent aussi en majuscules. Après une action, son résultat reste affiché sous le menu jusqu'à l'action suivante.

### Lancement d'un compte

Claude Code démarre dans le même terminal, avec `CLAUDE_CONFIG_DIR` pointé sur le dossier du compte, ou sans cette variable pour `.claude`. Juste avant, `clm` écrit les quotas du compte dans le fichier d'état de la barre d'état. L'exécutable est `~/.local/bin/claude` (`claude.exe` sous Windows) s'il existe, sinon le premier `claude` du PATH. Les arguments de `clm` qu'il ne reconnaît pas passent à Claude Code, et le code de sortie de Claude Code devient celui de `clm`.

Si le terminal ne permet pas le menu interactif, `clm` affiche la liste des comptes avec leurs quotas et demande un numéro.

## Rythme d'utilisation

À côté de chaque barre, un mot résume l'utilisation. Le menu projette le pourcentage actuel jusqu'à la fin de la fenêtre, au rythme constaté depuis son ouverture, et affiche :

| Mot | Cas | Couleur |
|---|---|---|
| `debut` | moins de 10 % de la fenêtre écoulée, trop tôt pour projeter | grise |
| `faible` | projection sous 70 % | verte |
| `normal` | projection de 70 % à 100 % inclus | grise |
| `fort` | projection au-dessus de 100 %, jusqu'à 130 % inclus : à ce rythme, le quota sera épuisé avant la fin | orange |
| `excessif` | projection au-dessus de 130 % | rouge |
| `epuise` | quota à 100 % ou plus, jusqu'à sa remise à zéro | rouge |

`epuise` passe avant `debut`. Aucun mot n'est affiché sans pourcentage, sans heure de remise à zéro, ou quand cette heure est déjà passée. `clm --usage` ajoute le même mot après chaque quota.

## Ajouter un compte

La touche `a` demande un nom (Entrée garde le nom par défaut `compteN`, `q` annule). Le menu crée alors le dossier `.claude-compteN`, où N vaut le nombre de comptes plus un, augmenté tant qu'un dossier de ce nom existe déjà, puis :

1. relie les éléments partagés avec `.claude` (voir "Dossiers partagés") ;
2. copie le `settings.json` de `.claude`, hooks compris ;
3. écrit un `.claude.json` qui marque l'accueil de Claude Code comme déjà fait ;
4. enregistre le compte dans `.claude-accounts.json` ;
5. lance `claude auth login`, qui ouvre la connexion dans le navigateur.

Si claude.ai est déjà connecté dans le navigateur sur un autre compte, c'est cet autre compte qui sera enregistré. Ouvrir le lien de connexion dans une fenêtre privée évite le piège. Une connexion abandonnée laisse le compte dans le menu avec le message "cree, mais non connecte" : il suffit de le lancer et de faire `/login`. Le menu ne vérifie pas que le nom est unique, et deux comptes du même nom se confondent dans le cache des quotas et dans `--save=`.

## Retirer un compte

La touche `x` ouvre une page qui liste les comptes, curseur sur celui du menu. On choisit avec les flèches et Entrée, ou avec un chiffre, Échap ou `q` annule. Une seconde page propose deux sorties :

- `1` retire le compte du menu et laisse son dossier en place. Il revient si on remet son entrée dans `.claude-accounts.json`.
- `2` le retire puis efface son dossier, avec connexion, historique et réglages. Avant d'effacer, le menu range une archive du compte dans Téléchargements, restaurable avec `r`, et n'efface rien si l'archive échoue.

Les dossiers et fichiers partagés sont des liens vers `.claude` : l'effacement retire le lien sans toucher à ce qu'il vise. Sous macOS, les entrées du trousseau propres au compte sont supprimées aussi. Elles ne sont pas dans l'archive, donc un compte restauré devra se reconnecter, et la page le rappelle.

Seuls les dossiers nommés `.claude-<nom>` peuvent être effacés depuis le menu. Pour `.claude` et tout autre dossier, la page n'offre que `1`. Le dernier compte restant ne peut pas être retiré. Si l'effacement échoue en route, par exemple sur un fichier ouvert par une session Claude Code, le compte est déjà retiré du menu et le message indique ce qui reste. Le cache des quotas et les clés du compte dans le fichier d'état de la barre ne sont pas nettoyés.

## Ligne de commande

```
clm                          menu
clm -2                       lance le compte 2 sans passer par le menu
clm -2 --resume              les arguments non reconnus passent à Claude Code
clm --no-update              ne cherche pas de mise à jour de Claude Code
clm --usage                  quotas de tous les comptes, une ligne par compte
clm --save                   sauvegarde de tous les comptes
clm --save=compte2,compte3   sauvegarde de certains comptes
clm --restore=<fichier>      restauration de tous les comptes d'une archive
clm --restore=<fichier> --only=compte2
```

`-N` accepte un chiffre de 1 à 9. Un numéro sans compte affiche "pas de compte N" et sort avec le code 1. `--save=` et `--only=` prennent des noms de comptes, ceux affichés dans le menu, séparés par des virgules, sans tenir compte des majuscules. Un nom inconnu arrête la commande avec "compte inconnu : ..." et le code 1, sans rien sauvegarder ni restaurer.

`--usage`, `--save` et `--restore` font leur travail et sortent aussitôt, sans menu ni mise à jour de Claude Code. `--restore` ne demande pas de confirmation, mais garde comme dans le menu une copie de l'état actuel des comptes visés. `--usage` écrit une ligne par compte, de la forme `pro moi@exemple.fr Max 5x | 5h 70% reset 18:30 (dans 2h05), fort | 7d 30% reset 12/10 09:00 (dans 4j3h), normal`, suivie de "(lu il y a ...)" quand les chiffres viennent du cache, ou "(fenetre passee, lu il y a ...)" quand une remise à zéro a eu lieu depuis, ou du message d'erreur à la place des quotas. Il n'y a pas d'option `--help`.

## Mise à jour de Claude Code

Avant d'afficher le menu, et avant un lancement direct comme `clm -2`, `clm` lance `claude update` avec l'environnement du premier compte. Tous les comptes partagent le même exécutable, donc la mise à jour ne tourne qu'une fois, et son résultat s'affiche en face de chaque compte puis reste sous le menu.

Pendant l'étape, une ligne suit l'avancement. Elle indique "recherche de mise a jour" tant que `claude update` n'a rien annoncé, puis "mise a jour <version>" avec un témoin d'attente et la dernière ligne écrite par `claude update`. Pour une installation native, `clm` surveille le fichier en cours de téléchargement : la ligne passe à "telechargement <version>" avec le pourcentage et les mégaoctets reçus, puis à "installation <version>" à 100 %. La taille attendue est lue dans le manifeste publié par Anthropic, et sans elle seuls les mégaoctets s'affichent. Une installation par paquet (npm) reste sur "mise a jour <version>" jusqu'à la fin.

Le résultat est l'un de ces messages :

- "Claude Code mis a jour, X -> Y" ;
- "Claude Code a jour (X)" ;
- "Claude Code X disponible, a installer avec ..." quand Claude Code est géré par un gestionnaire de paquets comme Homebrew : `clm` ne l'installe pas lui-même ;
- "mise a jour de Claude Code : verification impossible" : `claude update` n'a rien annoncé en 20 secondes ;
- "mise a jour de Claude Code abandonnee, telechargement bloque" : le fichier téléchargé n'a pas grossi depuis 90 secondes ;
- "mise a jour de Claude Code deja en cours ailleurs" : une autre session met déjà Claude Code à jour ;
- "echec de la mise a jour : ..." ou "echec de claude update (code N)" ;
- "Claude Code introuvable, pas de mise a jour" ;
- "claude update : ..." avec sa dernière ligne, ou "claude update termine", quand sa sortie n'a pas été reconnue.

Les échecs s'affichent en rouge et une mise à jour faite en vert.

Un téléchargement complet n'est jamais interrompu. `claude update` tourne en priorité basse, et son arbre de processus est arrêté en cas d'abandon. `--no-update`, `--usage`, `--save` et `--restore` sautent l'étape.

## Sauvegarde et restauration

### Ce que contient une sauvegarde

La touche `s` ouvre une page où tous les comptes sont cochés. Espace coche ou décoche le compte sous le curseur, `t` inverse tout (tout cocher si un compte manque, sinon tout décocher), Entrée valide s'il reste au moins un compte coché, Échap annule.

L'archive reprend l'arborescence du dossier personnel. Elle contient :

- le dossier de chaque compte coché : jetons (hors macOS), réglages, plugins, MCP, historique des conversations ;
- `.claude.json` et `.mcp.json` quand `.claude` est coché ;
- la liste des comptes, `.claude-accounts.json` ;
- les scripts du menu présents dans `~/.local/bin`.

Sont exclus, à toute profondeur, les dossiers et fichiers nommés `cache`, `paste-cache`, `session-env`, `shell-snapshots`, `ide` et `*.lock`, et les `.exe` de `.local/bin`. Le dossier `plugins/cache`, où Claude Code range le code des plugins installés, en fait partie : la liste des plugins est sauvegardée, leur code téléchargé ne l'est pas.

L'archive s'appelle `claude-comptes-<date>-<heure>`. C'est un `.zip` sous Windows et macOS, et sous Linux quand `bsdtar` est installé (paquet `libarchive-tools`). Avec le seul GNU tar, Linux écrit un `.tar.gz` et ne sait pas relire un `.zip` venu d'un autre poste. Elle va dans le dossier Téléchargements : celui déclaré dans Windows (même déplacé), celui de `XDG_DOWNLOAD_DIR` sous Linux, à défaut `~/Downloads`, créé s'il manque. Une barre suit l'écriture. Des avertissements signalent des fichiers ignorés, souvent parce qu'une session Claude Code les tient ouverts.

L'archive n'est pas chiffrée et contient les jetons de connexion, sauf sous macOS où ils restent dans le trousseau : quiconque la récupère peut se servir des comptes.

### Restaurer

La touche `r` liste les 9 sauvegardes `claude-comptes-*` les plus récentes du dossier Téléchargements, avec leur date et leur taille. Un chiffre choisit l'archive, toute autre touche annule. La page suivante coche les comptes présents dans l'archive, avec les mêmes touches que pour la sauvegarde. Il faut ensuite confirmer par `o`.

La restauration fait trois choses :

1. Elle copie l'état actuel des comptes visés déjà présents sur le poste dans une archive `claude-comptes-avant-restauration-*`. Un compte qui n'existe pas encore n'a rien à copier.
2. Elle extrait les dossiers des comptes choisis, plus `.claude.json` et `.mcp.json` si `.claude` en fait partie. Les fichiers de l'archive remplacent ceux du poste, et les fichiers du poste absents de l'archive restent en place. La liste des comptes et les scripts de l'archive ne sont pas extraits.
3. Elle ajoute à la liste des comptes ceux qui n'y étaient pas, sous le nom qu'ils avaient dans l'archive, puis recrée les liens partagés de tous les comptes.

Une archive placée ailleurs se restaure par `clm --restore=<chemin>`.

### Dossiers partagés

Les comptes secondaires partagent avec `.claude` les dossiers `agents`, `commands`, `hooks`, `rules` et `skills`, par des jonctions sous Windows et des liens symboliques ailleurs, et les fichiers `ANTI-EMPREINTE.md`, `CLAUDE.md`, `settings.local.json` et `statusline.json` par des liens physiques. Ces liens sont créés à l'ajout d'un compte et après une restauration, seulement pour les éléments qui existent dans `.claude`. Les éléments partagés ne sont sauvegardés qu'une fois, avec `.claude`.

## Liste des comptes

Les comptes sont rangés dans `~/.claude-accounts.json` (`%USERPROFILE%\.claude-accounts.json` sous Windows), un tableau JSON dans l'ordre du menu :

```json
[
  { "Label": "compte1", "Dir": ".claude" },
  { "Label": "pro", "Dir": ".claude-compte2" }
]
```

`Label` est le nom affiché, `Dir` le dossier, relatif au dossier personnel. Quand ce fichier manque ou est illisible, `clm` le recrée : `.claude` devient `compte1`, puis chaque dossier `.claude-compte2` à `.claude-compte9` présent devient un compte. Ensuite, seul le fichier compte : un dossier créé à la main n'apparaît qu'une fois ajouté au fichier.

## Quotas

Les pourcentages viennent de l'API `api.anthropic.com/api/oauth/usage`, avec le jeton du compte. Il est lu dans `.credentials.json` du dossier du compte, et sous macOS d'abord dans le trousseau, où Claude Code le range. Sous Windows et Linux, un jeton expiré est renouvelé par `clm` lui-même avec le refresh token du compte, comme Claude Code le fait au démarrage, puis `.credentials.json` est réécrit. Le serveur peut remplacer le refresh token à cette occasion : une session Claude Code restée ouverte sur ce compte avec l'ancien peut alors redemander un `/login`. Sous macOS, `clm` ne renouvelle rien et n'écrit rien dans le trousseau. Les comptes sont interrogés l'un après l'autre, avec 10 secondes au plus par appel.

Les résultats sont gardés deux minutes dans un cache, utilisé aussi par `--usage` : `%LOCALAPPDATA%\claude-menu\usage.json` sous Windows, `~/Library/Caches/claude-menu/usage.json` sous macOS et `${XDG_CACHE_HOME:-~/.cache}/claude-menu/usage.json` sous Linux. Quand l'API limite les appels, ou que le jeton a expiré sans pouvoir être renouvelé, le menu affiche les dernières valeurs du cache, avec leur âge. Une fenêtre dont la remise à zéro a eu lieu depuis cette lecture repart à 0 %, sans heure, avec la mention "fenetre passee".

Un compte sans chiffres affiche l'un de ces messages :

- "non connecte" : pas de jeton pour ce compte ;
- "jeton a rafraichir, lancer le compte une fois" : le jeton a expiré, n'a pas pu être renouvelé, et le cache est vide ;
- "jeton refuse, lancer le compte une fois" : l'API refuse le jeton ;
- "quota inconnu, l'API de suivi refuse les appels (reessai dans ...)" : l'API limite les appels et le cache est vide ;
- "API de suivi injoignable" : pas de réseau, ou une autre erreur.

## Couleurs claires ou sombres

Le menu choisit sa palette au démarrage, dans cet ordre :

1. la variable `STATUSLINE_BG` (`light`, `clair`, `dark` ou `sombre`) ;
2. `terminal_background` dans `~/.claude/statusline.json` quand il vaut `light` ou `dark` ;
3. la réponse de `~/.claude/bin/statusline --theme` si la [barre d'état](https://github.com/LetermeFlorent/claude-statusline) est installée, qui sait lire les réglages du terminal ;
4. le thème du système : sous Windows le réglage des applications, sous macOS l'apparence (`defaults read -g AppleInterfaceStyle`), sous Linux `gsettings` (`color-scheme`), puis `GTK_THEME`, puis les couleurs de KDE (`kdeglobals`).

À défaut, la palette sombre s'applique.

## Barre d'état à jour au lancement

Quand `clm` lance un compte, il écrit d'abord les quotas 5 h et 7 j de ce compte dans le fichier d'état de la [barre d'état](https://github.com/LetermeFlorent/claude-statusline), de sorte que les valeurs sont justes dès le premier affichage. Ce fichier est `%LOCALAPPDATA%\claude-statusline\state` sous Windows, `~/Library/Application Support/claude-statusline/state` sous macOS et `${XDG_STATE_HOME:-~/.local/state}/claude-statusline/state` sous Linux. Rien n'est écrit si son dossier n'existe pas, c'est-à-dire si la barre n'a jamais tourné, ni si les quotas du compte ne sont pas lisibles.

Chaque compte y a ses propres clés, suffixées par le nom de son dossier : `q5_at@claude-compte2` (heure de remise à zéro), `q5_pct@claude-compte2` (pourcentage), de même pour `q7_`, et `q_at@claude-compte2` (heure de l'écriture). Le script ne réécrit que les clés du compte lancé, retire les anciennes clés sans suffixe, et garde le reste du fichier.

Pour le même effet avec un simple `claude`, l'installeur ajoute un hook `SessionStart` (déclencheur `startup`, délai 15 secondes) dans le `settings.json` de `.claude` et de chaque `.claude-compte*` qui en a un. Les dossiers sont trouvés par leur nom, sans lire la liste des comptes, et un compte ajouté plus tard par `a` reçoit le hook avec la copie du `settings.json` de `.claude`. Un fichier qui contient déjà le hook n'est pas touché. Les autres sont d'abord copiés en `settings.json.bak-seed`, puis réécrits par PowerShell : les valeurs restent, la mise en forme change. Ce hook lance `claude-statusline-seed.ps1`, qui reconnaît le compte par `CLAUDE_CONFIG_DIR` et ne fait rien pour un dossier absent de la liste des comptes. Si le compte n'a aucune fenêtre de 5 h ouverte, la barre garde `--%` sur 5 h jusqu'au premier message.

## Fichiers et variables

`clm` écrit ou modifie ces fichiers :

| Fichier | Rôle |
|---|---|
| `~/.local/bin/clm`, `clm.cmd`, `claude-menu.cmd`, `claude-*.ps1` | le menu, copié par l'installeur |
| `~/.claude-accounts.json` | liste des comptes |
| `~/.claude-compteN/` | dossiers des comptes ajoutés |
| `settings.json` de chaque compte, et sa copie `settings.json.bak-seed` | hook `SessionStart`, ajouté par l'installeur |
| cache `claude-menu/usage.json` | quotas des deux dernières minutes |
| `.credentials.json` de chaque compte, hors macOS | jeton renouvelé quand il a expiré |
| fichier d'état `claude-statusline/state` | quotas pour la barre d'état |
| `claude-comptes-*.zip` ou `.tar.gz` dans Téléchargements | sauvegardes |

Il lit `USERPROFILE` puis `HOME` pour le dossier personnel, `LOCALAPPDATA` sous Windows, `XDG_CACHE_HOME`, `XDG_STATE_HOME` et `XDG_CONFIG_HOME` sous Linux, `STATUSLINE_BG` et `GTK_THEME` pour les couleurs, et `CLAUDE_CONFIG_DIR` dans le hook. Il pose ou retire lui-même `CLAUDE_CONFIG_DIR` pour lancer un compte.

## Tests

`tests/run.ps1` vérifie les fonctions sans réseau ni vrai compte, dans un dossier temporaire, et sort avec un code non nul en cas d'échec. Il tourne avec `powershell -File tests\run.ps1` comme avec `pwsh -File tests/run.ps1`. Le calcul du suffixe de compte du fichier d'état a en plus un test Pester, `tests/StateTag.Tests.ps1`.

La CI lance ces tests à chaque envoi sur `main` et sur chaque pull request, sous Linux, macOS et Windows, avec PowerShell 7 partout et Windows PowerShell 5.1 en plus sous Windows. Elle vérifie aussi la syntaxe de `bin/clm` et de `install.sh`.

## Limites

Les touches `1` à `9` et `-1` à `-9` ne couvrent que les neuf premiers comptes. La page de restauration ne propose que les neuf sauvegardes les plus récentes. Les quotas viennent d'une API non documentée d'Anthropic, qui peut changer ou limiter les appels. Le renouvellement des jetons passe lui aussi par un point d'accès OAuth non documenté : s'il change, le menu retombe sur le cache et le message "jeton a rafraichir". Sous macOS, les sauvegardes ne contiennent pas les jetons de connexion.
