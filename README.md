# claude-account-menu

Menu en terminal pour jongler entre plusieurs comptes Claude Code sur un même poste, sous Windows, Linux ou macOS. Chaque compte vit dans son propre dossier de configuration (`.claude`, `.claude-compte2`, etc.), et `clm` lance Claude Code sur celui qu'on choisit, avec le quota 5 h et 7 j de chacun affiché à côté. Il sert aussi à ajouter, retirer, renommer, sauvegarder et restaurer des comptes, et met Claude Code à jour avant chaque lancement.

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

Le menu s'ouvre tout de suite, en plein écran, pendant que la mise à jour de Claude Code (voir plus bas) et la lecture des quotas tournent en arrière-plan. Un compte dont les quotas sont dans le cache depuis moins de trois minutes s'affiche aussitôt. Les autres montrent une barre qui scintille et "lecture...", puis leurs barres se remplissent à l'arrivée des chiffres. L'en-tête "Comptes Claude Code" est suivi de la version installée, "clm v34" (voir "Mise à jour de clm"), et porte à droite l'heure, tenue à jour. Quand une version plus récente est publiée pendant que le menu est ouvert, un bouton "[maj dispo]" apparaît à côté. Quand la fenêtre est étroite, la version disparaît, le bouton reste. Chaque compte a son propre compteur de relecture, à droite de son nom : "maj 2m05s" compte le temps jusqu'à sa prochaine lecture, "lecture..." s'affiche pendant qu'il est relu, "en pause" pendant une mise à jour de Claude Code. Quand l'API de suivi a refusé de le relire, le compteur passe en orange, "pause API 4m10s", et les barres gardent les dernières valeurs connues. Quand il n'a pas pu être relu pour une autre raison, il passe en rouge, "reessai 2m55s". Chaque compte occupe un bloc :

- une ligne avec son numéro, son nom, et à droite son abonnement (`Max 20x`, `Max 5x`, `Pro`, etc.), précédé d'un badge rouge "quota 7d atteint" ou "quota 5h atteint" quand un quota est à 100 % ;
- l'adresse e-mail du compte, avec à droite "lu il y a ..." quand les chiffres viennent du cache depuis plus d'une minute, ou "fenetre passee, lu il y a ..." quand une remise à zéro a eu lieu depuis ;
- une barre 5 h et une barre 7 j, chacune avec le pourcentage, le temps avant remise à zéro (`45m`, `2h05m`, `3d04h`, `0m`, ou `-` s'il est inconnu) et le mot qui résume le rythme d'utilisation ;
- à la place des barres, un message d'erreur en rouge quand les quotas ne sont pas lisibles.

Les barres changent de teinte à 30 % puis à 70 %, comme la barre d'état : violet, mauve et rouge framboise pour le 5 h, vert, ocre et rouge pour le 7 j. Elles reprennent aussi son dessin : une suite de carrés dont la teinte s'éclaircit vers la droite sur fond sombre et fonce sur fond clair, la dernière case pleine réduite à un petit carré. À 100 %, le pourcentage prend la couleur de la barre.

Le menu suit la taille du terminal, jusqu'à 100 colonnes de large. Quand la hauteur manque pour les blocs complets, chaque compte passe sur trois lignes, nom et e-mail sur la première, les deux barres côte à côte sur la deuxième, et la liste défile, une flèche au bout du filet signalant les comptes cachés. Sous 40 colonnes, ou dans un terminal très bas, il ne reste qu'une ligne par compte, quotas en texte. Le compte sélectionné garde sa pleine intensité, les autres sont un peu atténués, et le repère glisse d'un compte à l'autre.

Le curseur part sur le premier compte lisible dont aucun quota n'est à 100 %, à défaut sur le premier, et suit cette règle tant que les quotas arrivent, sauf si on l'a déjà déplacé. Tant que le menu reste ouvert, chaque compte est relu pour lui seul, 3 minutes après sa lecture précédente, plus un délai pris au hasard jusqu'à 25 secondes. Au premier tour, les comptes sont en plus décalés d'une fraction des 3 minutes, un tiers par compte avec trois comptes, pour ne pas tomber sur l'API en même temps. Un compte dont les chiffres viennent du cache est relu à l'expiration du cache, et un compte en pause après un refus de l'API à la fin de sa pause (voir plus bas). Seules les barres dont la valeur a changé s'animent, et seules les lignes modifiées sont réécrites à l'écran. Ils sont aussi relus après chaque ajout, retrait, sauvegarde ou restauration.

Les transitions durent de 120 à 400 millisecondes. Elles suivent le réglage du système (animations de Windows, "réduire les animations" de macOS, `enable-animations` de GNOME) et la variable `CLM_ANIM` passe outre : `0` les coupe, `1` les force. Sans animation, le menu s'affiche directement dans son état final.

### Touches

Le pied du menu rappelle les touches principales, sur une ligne à partir de 99 colonnes et sur deux en dessous :

| Touche | Action |
|---|---|
| flèches haut et bas | déplacer le curseur, en boucle |
| Entrée | lancer le compte sélectionné |
| `1` à `9` | lancer directement le compte de ce numéro |
| `a` | ajouter un compte |
| `x` | retirer un compte |
| `n` | renommer un compte |
| `m` | relire tout de suite les quotas du compte sélectionné |
| `u` | installer la nouvelle version de clm signalée par "[maj dispo]" et relancer le menu |
| `s` | sauvegarder des comptes |
| `r` | restaurer une sauvegarde |
| `q`, Échap ou Ctrl+C | quitter |

Les lettres marchent aussi en majuscules. Après une action, son résultat reste affiché sous le menu jusqu'à l'action suivante. Dans les pages de sauvegarde, de restauration et de retrait, Ctrl+C annule la page puis ferme le menu. Pendant une sauvegarde ou une mise à jour, il laisse l'opération se terminer avant de fermer.

La touche `m` n'attend pas la fin du compteur "maj" : le compte sélectionné passe en "lecture..." et ses quotas sont redemandés à l'API, dès que la lecture en cours des autres comptes est finie. Le résultat s'affiche sous le menu, par exemple "compte1 : quotas relus a 14:32:05 (5h 7 %, 7j 3 %)", même quand les chiffres n'ont pas bougé. Deux garde-fous évitent de provoquer un refus de l'API. Un compte lu il y a moins de 30 secondes garde la valeur du cache. Un compte en "pause API" n'est pas relu, et le menu affiche le temps qui reste avant le prochain essai.

### Souris

Sous Windows, le menu lit aussi la souris. Un clic sur un compte le sélectionne, un double clic sur le compte déjà sélectionné le lance. La molette déplace le curseur. Un clic sur une touche du pied de page, ou sur son libellé, fait comme la touche. Dans les pages de sauvegarde, de restauration et de retrait, seuls la molette et le pied de page répondent.

Pour recevoir les clics, le menu coupe le mode d'édition rapide de la console tant qu'il est ouvert, puis le rétablit en sortant. Sélectionner du texte demande alors Maj et un glisser dans Windows Terminal. Le lecteur de la souris est compilé au premier lancement, puis gardé dans `%LOCALAPPDATA%\claude-menu`. Sous macOS et Linux, seul le clavier compte.

### Lancement d'un compte

Claude Code démarre dans le même terminal, avec `CLAUDE_CONFIG_DIR` pointé sur le dossier du compte, ou sans cette variable pour `.claude`. Juste avant, `clm` écrit les quotas du compte dans le fichier d'état de la barre d'état. L'exécutable est `~/.local/bin/claude` (`claude.exe` sous Windows) s'il existe, sinon le premier `claude` du PATH. Les arguments de `clm` qu'il ne reconnaît pas passent à Claude Code, et le code de sortie de Claude Code devient celui de `clm`.

Si le terminal ne permet pas le menu interactif (entrée ou sortie redirigée, hôte autre que la console, terminal sans séquences VT), `clm` affiche la liste des comptes avec leurs quotas et demande un numéro.

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

Si claude.ai est déjà connecté dans le navigateur sur un autre compte, c'est cet autre compte qui sera enregistré. Ouvrir le lien de connexion dans une fenêtre privée évite le piège. Une connexion abandonnée laisse le compte dans le menu avec le message "cree, mais non connecte" : il suffit de le lancer et de faire `/login`. Le menu ne vérifie pas que le nom est unique, et deux comptes du même nom se confondent dans le cache des quotas et dans `--save=` : la touche `n` permet d'en renommer un.

## Retirer un compte

La touche `x` ouvre une page qui liste les comptes, curseur sur celui du menu. On choisit avec les flèches et Entrée, ou avec un chiffre, Échap ou `q` annule. Une seconde page propose deux sorties :

- `1` retire le compte du menu et laisse son dossier en place. Il revient si on remet son entrée dans `.claude-accounts.json`.
- `2` le retire puis efface son dossier, avec connexion, historique et réglages. Avant d'effacer, le menu range une archive du compte dans Téléchargements, restaurable avec `r`, et n'efface rien si l'archive échoue.

Les dossiers et fichiers partagés sont des liens vers `.claude` : l'effacement retire le lien sans toucher à ce qu'il vise. Sous macOS, les entrées du trousseau propres au compte sont supprimées aussi. Elles ne sont pas dans l'archive, donc un compte restauré devra se reconnecter, et la page le rappelle.

Seuls les dossiers nommés `.claude-<nom>` peuvent être effacés depuis le menu. Pour `.claude` et tout autre dossier, la page n'offre que `1`. Le dernier compte restant ne peut pas être retiré. Si l'effacement échoue en route, par exemple sur un fichier ouvert par une session Claude Code, le compte est déjà retiré du menu et le message indique ce qui reste. Le cache des quotas et les clés du compte dans le fichier d'état de la barre ne sont pas nettoyés.

## Renommer un compte

La touche `n` ouvre la même liste que le retrait, curseur sur le compte du menu. Après le choix, le menu laisse la place à une question, "Nouveau nom", et Entrée sans rien taper annule. Seul le nom affiché change, dans `.claude-accounts.json` : le dossier, la connexion et l'adresse e-mail restent les mêmes. Les quotas en cache suivent le nouveau nom, sans nouvelle lecture.

Le nouveau nom est refusé s'il est vide, s'il contient une virgule, qui sépare les noms dans `--save=` et `--only=`, ou s'il est déjà pris par un autre compte, sans tenir compte de la casse. Changer seulement la casse d'un nom est permis.

## Ligne de commande

```
clm                          menu
clm -2                       lance le compte 2 sans passer par le menu
clm -2 --resume              les arguments non reconnus passent à Claude Code
clm --no-update              ne cherche de mise à jour ni pour clm ni pour Claude Code
clm --usage                  quotas de tous les comptes, une ligne par compte
clm --save                   sauvegarde de tous les comptes
clm --save=compte2,compte3   sauvegarde de certains comptes
clm --restore=<fichier>      restauration de tous les comptes d'une archive
clm --restore=<fichier> --only=compte2
```

`-N` accepte un chiffre de 1 à 9. Un numéro sans compte affiche "pas de compte N" et sort avec le code 1. `--save=` et `--only=` prennent des noms de comptes, ceux affichés dans le menu, séparés par des virgules, sans tenir compte des majuscules. Un nom inconnu arrête la commande avec "compte inconnu : ..." et le code 1, sans rien sauvegarder ni restaurer.

`--usage`, `--save` et `--restore` font leur travail et sortent aussitôt, sans menu ni mise à jour de Claude Code. `--restore` ne demande pas de confirmation, mais garde comme dans le menu une copie de l'état actuel des comptes visés. `--usage` écrit une ligne par compte, de la forme `pro moi@exemple.fr Max 5x | 5h 70% reset 18:30 (dans 2h05), fort | 7d 30% reset 12/10 09:00 (dans 4j3h), normal`, suivie de "(lu il y a ...)" quand les chiffres viennent du cache, ou "(fenetre passee, lu il y a ...)" quand une remise à zéro a eu lieu depuis, ou du message d'erreur à la place des quotas. Il n'y a pas d'option `--help`.

## Mise à jour de clm

Avant d'ouvrir le menu, avant un lancement direct comme `clm -2` et avant `--restore`, `clm` demande à GitHub le dernier commit de la branche `main`. S'il est plus récent que la version installée, `clm` télécharge le dépôt à ce commit, lance `install.ps1` (ou `install.sh`), puis redémarre avec les mêmes arguments. La version installée est rangée dans `clm.version`, à côté des scripts, sous la forme `<commit> <date unix> <numéro>`. Le numéro est le nombre de commits de `main` jusqu'à cette version : il s'affiche dans l'en-tête du menu, "clm v34", et augmente à chaque version publiée. L'installeur écrit ce fichier quand il tourne depuis un clone git, et l'efface sinon : une version inconnue est remplacée par la dernière au lancement suivant. Un fichier écrit avant l'arrivée du numéro affiche à la place les sept premiers caractères du commit.

GitHub a quatre secondes pour répondre. Sans réseau, ou quand l'API limite les appels, le menu s'ouvre avec la version installée, sans message. Un échec pendant l'installation s'affiche en jaune et le menu s'ouvre quand même. Une version installée plus récente que `main`, après un `install.ps1` depuis une branche de travail, n'est pas remplacée. `clm` ne se met à jour que s'il tourne depuis `.local/bin` : lancé depuis le clone, il ne touche à rien. `--no-update` saute l'étape, `--usage` et `--save` aussi.

Le menu ouvert redemande à GitHub le dernier commit de `main` toutes les dix minutes, en arrière-plan. Quand une version plus récente est sortie, le bouton "[maj dispo]" apparaît dans l'en-tête. Un clic dessus, ou la touche `u`, ferme le menu, installe la nouvelle version comme au lancement, puis rouvre `clm`. Si l'installation échoue, le message reste affiché trois secondes avant que le menu revienne. Cette vérification n'a lieu que si `clm` tourne depuis `.local/bin`.

Chaque sauvegarde emporte `clm.version`. La restauration refuse une archive faite avec un `clm` plus récent que celui installé, ou quand la version installée est inconnue, avec "sauvegarde faite avec clm ..." et la marche à suivre : relancer `clm`, qui se met à jour, puis restaurer. Une archive faite avant l'arrivée de `clm.version` se restaure sans contrôle.

## Mise à jour de Claude Code

À l'ouverture du menu, et avant un lancement direct comme `clm -2`, `clm` lance `claude update` avec l'environnement du premier compte. Tous les comptes partagent le même exécutable, donc la mise à jour ne tourne qu'une fois. Dans le menu, son résultat reste en bas jusqu'à l'action suivante. Hors menu, il s'affiche en face de chaque compte. Les touches tapées pendant la mise à jour sont traitées à la fin.

Pendant l'étape, une ligne suit l'avancement, en bas du menu, avec une barre qui se remplit ou va et vient quand le pourcentage est inconnu. Elle indique "recherche de mise a jour" tant que `claude update` n'a rien annoncé, puis "mise a jour <version>" avec un témoin d'attente et la dernière ligne écrite par `claude update`. Pour une installation native, `clm` surveille le fichier en cours de téléchargement : la ligne passe à "telechargement <version>" avec le pourcentage et les mégaoctets reçus, puis à "installation <version>" à 100 %. La taille attendue est lue dans le manifeste publié par Anthropic, et sans elle seuls les mégaoctets s'affichent. Une installation par paquet (npm) reste sur "mise a jour <version>" jusqu'à la fin.

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

L'archive n'est pas chiffrée et contient les jetons de connexion, sauf sous macOS où ils restent dans le trousseau : quiconque la récupère peut se servir des comptes. Ces jetons ne restent valables que jusqu'au prochain renouvellement : le serveur remplace le refresh token à chaque fois et invalide l'ancien. Un compte utilisé depuis la sauvegarde, par Claude Code ou par le menu qui lit ses quotas, demandera donc un `/login` une fois restauré, et la page de restauration le rappelle.

### Restaurer

La touche `r` liste les 9 sauvegardes `claude-comptes-*` les plus récentes du dossier Téléchargements, avec leur date et leur taille. Les flèches et Entrée, ou un chiffre, choisissent l'archive, Échap ou `q` revient au menu. La page suivante coche les comptes présents dans l'archive, avec les mêmes touches que pour la sauvegarde. Il faut ensuite confirmer par `o`.

La restauration fait trois choses :

1. Elle copie l'état actuel des comptes visés déjà présents sur le poste dans une archive `claude-comptes-avant-restauration-*`. Un compte qui n'existe pas encore n'a rien à copier.
2. Elle extrait les dossiers des comptes choisis, plus `.claude.json` et `.mcp.json` si `.claude` en fait partie. Les fichiers de l'archive remplacent ceux du poste, et les fichiers du poste absents de l'archive restent en place. La liste des comptes et les scripts de l'archive ne sont pas extraits.
3. Elle ajoute à la liste des comptes ceux qui n'y étaient pas, sous le nom qu'ils avaient dans l'archive, puis recrée les liens partagés de tous les comptes.

Une archive placée ailleurs se restaure par `clm --restore=<chemin>`.

### Dossiers partagés

Les comptes secondaires partagent avec `.claude` les dossiers `agents`, `commands`, `hooks`, `plugins`, `rules` et `skills`, par des jonctions sous Windows et des liens symboliques ailleurs, et les fichiers `ANTI-EMPREINTE.md`, `CLAUDE.md`, `settings.local.json` et `statusline.json` par des liens physiques. Ces liens sont créés à l'ajout d'un compte, après une restauration et à chaque lancement d'un compte, seulement pour les éléments qui existent dans `.claude`. Un vrai dossier déjà présent à la place d'un lien est renommé en `<nom>.bak-sync` avant d'être relié, et laissé tel quel si le renommage échoue. Claude Code remplace parfois un fichier au lieu de le réécrire, ce qui casse le lien physique : la copie la plus récente est alors gardée et le lien recréé. Les éléments partagés ne sont sauvegardés qu'une fois, avec `.claude`.

### Réglages et MCP synchronisés

Chaque compte garde son `settings.json` et son `.claude.json`, mais `clm` les synchronise à chaque lancement d'un compte. Dans `settings.json`, tout est commun sauf `model`, `modelSettings` et `theme`, propres à chaque compte. Dans `.claude.json`, seul `mcpServers` est commun : connexion, projets et le reste ne bougent pas.

La règle est celle du dernier modifié. `.claude-sync-state.json` garde la dernière valeur commune. Parmi les comptes qui s'en écartent, celui dont le fichier est le plus récent gagne, et sa valeur est recopiée dans les autres. Avant sa première réécriture par la synchronisation, un fichier est copié en `<fichier>.bak-sync`. Un verrou, `.claude-sync.lock`, empêche deux lancements de synchroniser en même temps : au bout de 5 secondes d'attente, le second lance le compte sans synchroniser et l'indique.

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

Les résultats sont gardés trois minutes dans un cache, partagé par le menu, `--usage` et le hook de la barre d'état : `%LOCALAPPDATA%\claude-menu\usage.json` sous Windows, `~/Library/Caches/claude-menu/usage.json` sous macOS et `${XDG_CACHE_HOME:-~/.cache}/claude-menu/usage.json` sous Linux. L'API limite les appels par jeton, et une relecture trop rapprochée la fait répondre 429 pendant de longues minutes. Après un refus, le compte n'est plus interrogé pendant 1 minute, puis 2, 4, 8 et enfin 10 minutes au plus si les refus se suivent, avec quelques secondes prises au hasard en plus, ou pendant le délai `Retry-After` envoyé par l'API s'il est plus long (une heure au plus). Cette pause est notée dans le cache : une autre fenêtre `clm` ou le hook la respectent aussi. La première lecture réussie la lève. Pendant la pause, le menu affiche les dernières valeurs du cache, avec leur âge. Une fenêtre dont la remise à zéro a eu lieu depuis cette lecture repart à 0 %, sans heure, avec la mention "fenetre passee".

Un compte sans chiffres affiche l'un de ces messages :

- "non connecte" : pas de jeton pour ce compte ;
- "compte deconnecte, lancer le compte une fois" : le jeton a expiré et n'a pas pu être renouvelé. Le cache n'est pas montré dans ce cas, ses chiffres seraient périmés ;
- "jeton refuse, lancer le compte une fois" : l'API refuse le jeton ;
- "quota inconnu, l'API de suivi refuse les appels (reessai dans ...)" : l'API limite les appels et le cache n'a aucune valeur pour ce compte ;
- "API de suivi injoignable" : pas de réseau, ou une autre erreur.

## Couleurs claires ou sombres

Le menu choisit sa palette au démarrage, dans cet ordre :

1. la variable `STATUSLINE_BG` (`light`, `clair`, `dark` ou `sombre`) ;
2. le thème du système : sous Windows le réglage des applications, sous macOS l'apparence (`defaults read -g AppleInterfaceStyle`), sous Linux `gsettings` (`color-scheme`), puis `GTK_THEME`, puis les couleurs de KDE (`kdeglobals`).

À défaut, la palette sombre s'applique. `clm` ne lit ni `~/.claude/statusline.json` ni le programme de la [barre d'état](https://github.com/LetermeFlorent/claude-statusline) : ses couleurs sont celles de la barre, recopiées dans le menu.

Menu ouvert, `clm` relit le thème du système toutes les deux secondes et passe d'une palette à l'autre en fondu quand il change, fond compris. Seule `STATUSLINE_BG` fixe la palette et coupe ce suivi.

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
| `~/.claude-accounts.json.bad` | copie d'une liste illisible, mise de côté avant d'être recréée |
| `~/.claude-compteN/` | dossiers des comptes ajoutés |
| `settings.json` de chaque compte, et sa copie `settings.json.bak-seed` | hook `SessionStart`, ajouté par l'installeur |
| cache `claude-menu/usage.json` | derniers quotas lus et pauses après un refus de l'API |
| `claude-menu/clm-conin-*.dll`, sous Windows | lecteur de la souris, compilé une fois |
| `.credentials.json` de chaque compte, hors macOS | jeton renouvelé quand il a expiré |
| fichier d'état `claude-statusline/state` | quotas pour la barre d'état |
| `claude-comptes-*.zip` ou `.tar.gz` dans Téléchargements | sauvegardes |

Il lit `USERPROFILE` puis `HOME` pour le dossier personnel, `LOCALAPPDATA` sous Windows, `XDG_CACHE_HOME`, `XDG_STATE_HOME` et `XDG_CONFIG_HOME` sous Linux, `STATUSLINE_BG` et `GTK_THEME` pour les couleurs, `CLM_ANIM` pour les animations, et `CLAUDE_CONFIG_DIR` dans le hook. Il pose ou retire lui-même `CLAUDE_CONFIG_DIR` pour lancer un compte.

## Tests

`tests/run.ps1` vérifie les fonctions sans réseau ni vrai compte, dans un dossier temporaire, et sort avec un code non nul en cas d'échec. Il charge tous les fichiers `*.checks.ps1`, rangés par domaine dans `accounts`, `menu`, `setup`, `ui` et `usage`. Il tourne avec `powershell -File tests\run.ps1` comme avec `pwsh -File tests/run.ps1`. Le calcul du suffixe de compte du fichier d'état a en plus un test Pester, `tests/StateTag.Tests.ps1`.

La CI lance ces tests à chaque envoi sur `main` et sur chaque pull request, sous Linux, macOS et Windows, avec PowerShell 7 partout et Windows PowerShell 5.1 en plus sous Windows. Elle vérifie aussi la syntaxe de `bin/clm` et de `install.sh`.

## Limites

Les touches `1` à `9` et `-1` à `-9` ne couvrent que les neuf premiers comptes. La page de restauration ne propose que les neuf sauvegardes les plus récentes. Les quotas viennent d'une API non documentée d'Anthropic, qui peut changer ou limiter les appels. Le renouvellement des jetons passe lui aussi par un point d'accès OAuth non documenté : s'il change, le compte s'affiche "compte deconnecte". Ce point d'accès refuse les appels qui ne se présentent pas comme Claude Code : `clm` envoie donc le même en-tête `User-Agent` que lui, avec la version de Claude Code installée. Sous macOS, les sauvegardes ne contiennent pas les jetons de connexion.
