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

Pendant que `clm` charge ses scripts, une barre "demarrage" avance sur la ligne du terminal, puis laisse la place au menu. Chaque script n'est lu qu'une fois, ce qui tient ce chargement autour d'une seconde. Le menu s'ouvre ensuite en plein écran, dans un cadre fin aux coins arrondis qui entoure aussi les pages de sauvegarde, de restauration, de retrait et d'attente. Quand le terminal est trop petit pour le cadre (moins de 41 colonnes, ou trop peu de lignes), le menu passe en vue texte, sans cadre. Au lancement, au-dessus des comptes, une barre par étape suit les mises à jour, dans le style des barres 5 h et 7 j : "clm" d'abord, puis "Claude Code" et "Drive" en même temps, ce dernier quand la synchro automatique est active (voir plus bas). Chaque barre se remplit avec le pourcentage quand il est connu et le détail de l'étape à droite, en vert pour une mise à jour faite, en rouge pour un échec. Les comptes apparaissent dès que clm est vérifié, pendant que Claude Code et Drive avancent encore. Quand une nouvelle version de clm est sortie, elle s'installe et clm redémarre avant de les montrer. Une ligne à jour ou mise à jour reste une seconde, puis s'efface en fondu et les suivantes remontent. Une ligne en échec reste à l'écran, en rouge. Pour Claude Code, elle indique seulement "echec", et la raison s'affiche en bas du menu. La lecture des quotas commence dès l'ouverture et continue en arrière-plan. Un compte dont les quotas ont moins de trois minutes, dans le cache ou dans le fichier d'état de la barre d'état (voir "Quotas"), s'affiche aussitôt. Les autres montrent une barre qui scintille et "lecture...", puis leurs barres se remplissent à l'arrivée des chiffres. L'en-tête "Comptes Claude Code" est suivi de la version installée, "clm v34" (voir "Mise à jour de clm"), et porte à droite l'heure, tenue à jour. Quand une version plus récente est publiée pendant que le menu est ouvert, un bouton "[maj dispo]" apparaît à côté. Quand la fenêtre est étroite, la version disparaît, le bouton reste. Chaque compte a son propre compteur de relecture, à droite de son nom : "maj 2m05s" compte le temps jusqu'à sa prochaine lecture, "lecture..." s'affiche pendant qu'il est relu, "en pause" quand le menu attend la fin d'une lecture avant d'ouvrir une page ou de se fermer. Quand l'API de suivi a refusé de le relire, le compteur passe en orange, "pause API 4m10s", et les barres gardent les dernières valeurs connues. Quand il n'a pas pu être relu pour une autre raison, il passe en rouge, "reessai 2m55s". Chaque compte occupe un bloc :

- une ligne avec son numéro, son nom, et à droite son abonnement (`Max 20x`, `Max 5x`, `Pro`, etc.), précédé d'un badge rouge "quota 7d atteint" ou "quota 5h atteint" quand un quota est à 100 % ;
- l'adresse e-mail du compte, avec à droite "lu il y a ..." quand les chiffres, venus du cache ou de la barre d'état, ont plus d'une minute, ou "fenetre passee, lu il y a ..." quand une remise à zéro a eu lieu depuis ;
- une barre 5 h et une barre 7 j, chacune avec le pourcentage, le temps avant remise à zéro (`45m`, `2h05m`, `3d04h`, `0m`, ou `-` s'il est inconnu) et le mot qui résume le rythme d'utilisation ;
- à la place des barres, un message d'erreur en rouge quand les quotas ne sont pas lisibles.

Les barres changent de teinte à 30 % puis à 70 %, comme la barre d'état : violet, mauve et rouge framboise pour le 5 h, vert, ocre et rouge pour le 7 j. Elles reprennent aussi son dessin : une suite de carrés dont la teinte s'éclaircit vers la droite sur fond sombre et fonce sur fond clair, la dernière case pleine réduite à un petit carré. À 100 %, le pourcentage prend la couleur de la barre.

Le menu suit la taille du terminal, jusqu'à 105 colonnes de large. Quand la hauteur manque pour les blocs complets, chaque compte passe sur trois lignes, nom et e-mail sur la première, les deux barres côte à côte sur la deuxième, et la liste défile, une flèche au bout du filet signalant les comptes cachés. Sous 40 colonnes, ou dans un terminal très bas, il ne reste qu'une ligne par compte, quotas en texte. Le compte sélectionné garde sa pleine intensité, les autres sont un peu atténués, et le repère glisse d'un compte à l'autre.

Le curseur part sur le premier compte lisible dont aucun quota n'est à 100 %, à défaut sur le premier, et suit cette règle tant que les quotas arrivent, sauf si on l'a déjà déplacé. Tant que le menu reste ouvert, chaque compte est relu pour lui seul, 3 minutes après sa lecture précédente, plus un délai pris au hasard jusqu'à 25 secondes. Au premier tour, les comptes sont en plus décalés d'une fraction des 3 minutes, un tiers par compte avec trois comptes, pour ne pas tomber sur l'API en même temps. Un compte dont les chiffres viennent du cache est relu à l'expiration du cache, et un compte en pause après un refus de l'API à la fin de sa pause (voir plus bas). Seules les barres dont la valeur a changé s'animent, et seules les lignes modifiées sont réécrites à l'écran. Ils sont aussi relus après chaque ajout, retrait, sauvegarde ou restauration.

Les transitions durent de 120 à 400 millisecondes. Elles suivent le réglage du système (animations de Windows, "réduire les animations" de macOS, `enable-animations` de GNOME), sauf si ce PC a son propre choix, posé par `clm --anim on` ou `off` ou par la page web. La variable `CLM_ANIM` passe avant les deux : `0` les coupe, `1` les force. Sans animation, le menu s'affiche directement dans son état final. La barre de démarrage, qui tourne avant que le menu soit chargé, lit seulement `CLM_ANIM` et le choix du PC : sans animation, elle se remplit sans le reflet qui la parcourt.

### Touches

Le pied du menu rappelle les touches principales, sur deux lignes de longueur proche, ou trois quand la fenêtre est étroite :

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
| `y` | lancer une synchro Drive, ou connecter le Drive et saisir la phrase de synchro si ce PC ne l'a pas encore (voir "Synchronisation entre PC") |
| `p` | choisir les skills et les MCP synchronisés sur ce PC et sur les autres PC reliés (voir "Réglages de synchro par PC") |
| `s` | sauvegarder des comptes |
| `r` | restaurer une sauvegarde |
| `w` | ouvrir la page web de clm dans le navigateur (voir "Page web") |
| `q`, Échap ou Ctrl+C | quitter |

Les lettres marchent aussi en majuscules. Après une action, son résultat reste affiché sous le menu jusqu'à l'action suivante. Dans les pages de sauvegarde, de restauration et de retrait, Ctrl+C annule la page puis ferme le menu. Pendant une sauvegarde ou une mise à jour, il laisse l'opération se terminer avant de fermer.

La touche `m` n'attend pas la fin du compteur "maj" : le compte sélectionné passe en "lecture..." et ses quotas sont redemandés à l'API, dès que la lecture en cours des autres comptes est finie. Le résultat s'affiche sous le menu, par exemple "compte1 : quotas relus a 14:32:05 (5h 7 %, 7j 3 %)", même quand les chiffres n'ont pas bougé. Deux garde-fous évitent de provoquer un refus de l'API. Un compte lu il y a moins de 30 secondes, par `clm` ou par la barre d'état, garde cette valeur. Un compte en "pause API" n'est pas relu, et le menu affiche le temps qui reste avant le prochain essai.

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
4. enregistre le compte dans `clm/accounts.json` ;
5. lance `claude auth login`, qui ouvre la connexion dans le navigateur.

Si claude.ai est déjà connecté dans le navigateur sur un autre compte, c'est cet autre compte qui sera enregistré. Ouvrir le lien de connexion dans une fenêtre privée évite le piège. Une connexion abandonnée laisse le compte dans le menu avec le message "cree, mais non connecte" : il suffit de le lancer et de faire `/login`. Le menu ne vérifie pas que le nom est unique, et deux comptes du même nom se confondent dans le cache des quotas et dans `--save=` : la touche `n` permet d'en renommer un.

## Retirer un compte

La touche `x` ouvre une page qui liste les comptes, curseur sur celui du menu. On choisit avec les flèches et Entrée, ou avec un chiffre, Échap ou `q` annule. Une seconde page propose deux sorties :

- `1` retire le compte du menu et laisse son dossier en place. Il revient si on remet son entrée dans `clm/accounts.json`.
- `2` le retire puis efface son dossier, avec connexion, historique et réglages. Avant d'effacer, le menu range une archive du compte dans Téléchargements, restaurable avec `r`, et n'efface rien si l'archive échoue.

Les dossiers et fichiers partagés sont des liens vers `.claude` : l'effacement retire le lien sans toucher à ce qu'il vise. Sous macOS, les entrées du trousseau propres au compte sont supprimées aussi. Elles ne sont pas dans l'archive, donc un compte restauré devra se reconnecter, et la page le rappelle.

Seuls les dossiers nommés `.claude-<nom>` peuvent être effacés depuis le menu. Pour `.claude` et tout autre dossier, la page n'offre que `1`. Le dernier compte restant ne peut pas être retiré. Si l'effacement échoue en route, par exemple sur un fichier ouvert par une session Claude Code, le compte est déjà retiré du menu et le message indique ce qui reste. Le cache des quotas et les clés du compte dans le fichier d'état de la barre ne sont pas nettoyés.

## Renommer un compte

La touche `n` ouvre la même liste que le retrait, curseur sur le compte du menu. Après le choix, le menu laisse la place à une question, "Nouveau nom", et Entrée sans rien taper annule. Seul le nom affiché change, dans `clm/accounts.json` : le dossier, la connexion et l'adresse e-mail restent les mêmes. Les quotas en cache suivent le nouveau nom, sans nouvelle lecture.

Le nouveau nom est refusé s'il est vide, s'il contient une virgule, qui sépare les noms dans `--save=` et `--only=`, ou s'il est déjà pris par un autre compte, sans tenir compte de la casse. Changer seulement la casse d'un nom est permis.

## Changer l'ordre des comptes

Les comptes gardent dans le menu l'ordre de `clm/accounts.json`, qui donne aussi leur numéro pour `1` à `9` et `-N`. `clm --move <compte> <rang>` place un compte à ce rang, 1 en haut, et décale les autres. La page web fait de même avec ses boutons "Monter" et "Descendre".

## Ligne de commande

Tout ce que fait le menu se fait aussi sans lui, par une option. `clm --help` les décrit toutes, avec les touches du menu, les variables et les fichiers : une personne, un script ou un agent comme Claude Code y trouve de quoi tout piloter, sans skill ni serveur MCP à installer.

```
clm                          menu
clm --help                   toutes les options, aussi -h
clm -2                       lance le compte 2 sans passer par le menu
clm -2 --resume              les arguments non reconnus passent à Claude Code
clm --no-update              ne cherche de mise à jour ni pour clm ni pour Claude Code
clm --web                    menu, et sa page web dans le navigateur
clm --list                   numéro, nom, dossier et e-mail de chaque compte
clm --usage                  quotas de tous les comptes, une ligne par compte
clm --add [nom]              nouveau compte, connexion dans le navigateur
clm --rename <compte> <nom>  renomme un compte
clm --move <compte> <rang>   change sa place dans le menu, 1 en haut
clm --remove <compte> --yes  retire un compte du menu, son dossier reste
clm --remove <compte> --erase --yes
clm --save                   sauvegarde de tous les comptes
clm --save=compte2,compte3   sauvegarde de certains comptes
clm --backups                archives de Téléchargements, la plus récente d'abord
clm --restore=<fichier>      restauration de tous les comptes d'une archive
clm --restore=<fichier> --only=compte2
clm --version                versions de clm et de Claude Code
clm --update                 met à jour clm puis Claude Code de chaque compte
clm --drive-status           connexion Drive, nom du PC, synchro auto, dernière synchro
clm --drive-login            connecte ce PC à Google Drive, puis demande la phrase de synchro
clm --sync-key               saisit la phrase de synchro sur ce PC, ou la crée sur un Drive neuf
clm --sync-key-reset         change la phrase de synchro pour tous les PC
clm --sync-key-forget        oublie la phrase sur ce PC, la synchro s'y arrête
clm --sync                   synchro Drive tout de suite
clm --sync --force           même chose, au-delà du garde-fou des suppressions
clm --sync-auto=off          coupe la synchro Drive automatique, on la remet
clm --prefs                  réglages de synchro de ce PC, avec l'id de chaque case
clm --prefs-off global:roblox global:blender
clm --prefs-off "mcp:*"      décoche tous les MCP, globaux compris, "skill:*" tous les skills
clm --prefs-on <id>          recoche, ou annule un effacement demandé
clm --prefs-erase <id> --yes efface partout à la prochaine synchro
clm --palette auto|dark|light couleurs du menu sur ce PC, auto suit le système
clm --anim auto|on|off       animations du menu sur ce PC, auto suit le système
```

`-N` accepte un chiffre de 1 à 9. Un numéro sans compte affiche "pas de compte N" et sort avec le code 1. `--save=` et `--only=` prennent des noms de comptes, ceux affichés dans le menu, séparés par des virgules, sans tenir compte des majuscules. Un nom inconnu arrête la commande avec "compte inconnu : ..." et le code 1, sans rien sauvegarder ni restaurer.

`--usage`, `--save` et `--restore` font leur travail et sortent aussitôt, sans menu ni mise à jour de Claude Code. `--restore` ne demande pas de confirmation, mais garde comme dans le menu une copie de l'état actuel des comptes visés. `--usage` écrit une ligne par compte, de la forme `pro moi@exemple.fr Max 5x | 5h 70% reset 18:30 (dans 2h05), fort | 7d 30% reset 12/10 09:00 (dans 4j3h), normal`, suivie de "(lu il y a ...)" quand les chiffres viennent du cache ou de la barre d'état, ou "(fenetre passee, lu il y a ...)" quand une remise à zéro a eu lieu depuis, ou du message d'erreur à la place des quotas.

Un `<compte>` se donne par son numéro dans le menu, son nom ou son dossier (`.claude-compte2`). `--remove` sans `--yes` dit ce qu'il ferait et sort avec le code 1, sans rien toucher ; `--erase` refuse le dossier `.claude`, comme le menu, et range d'abord une archive dans Téléchargements. `--add` crée le compte puis ouvre la connexion dans le navigateur, qu'une personne doit finir. Les noms passent les mêmes contrôles qu'au renommage. `--update` redémarre `clm` après une nouvelle version, puis met à jour Claude Code. Avec `-N`, toutes les options vont à Claude Code : `clm -2 --help` affiche l'aide de Claude Code.

Chaque option écrit son résultat en texte simple et sort avec le code 0, ou 1 avec la raison sur la dernière ligne. `--list`, `--version`, `--backups`, `--drive-status` et `--prefs` lisent seulement les fichiers de ce PC, sans réseau.

## Page web

La touche `w`, en couleur dans le pied du menu, ouvre dans le navigateur une page qui règle tout ce que fait le menu. `clm --web` lance le menu et ouvre la page du même coup. Le terminal reste utilisable pendant ce temps : chaque clic de la page passe par le menu, qui l'exécute comme une touche et affiche le résultat sous les comptes, et la page le reprend en haut.

Aucun serveur n'est à installer ni à lancer. Tant que le menu est ouvert, `clm` écoute lui-même sur `127.0.0.1`, sur un port libre choisi par le système, et n'accepte que les demandes qui portent le jeton de l'adresse ouverte. Ce jeton change à chaque ouverture. La page est faite de fichiers simples, rangés dans `~/.local/bin/clm-web`, sans rien charger d'internet.

La page range ses réglages dans quatre onglets, en haut : Comptes, Drive, Affichage et Sauvegardes. Les flèches gauche et droite passent d'un onglet à l'autre, et l'onglet ouvert reste le même quand on recharge la page. L'onglet Comptes montre les quotas 5 h et 7 j de chaque compte, avec les teintes du menu, et permet de relire, renommer, monter, descendre ou retirer un compte, et d'en ajouter un, dont la connexion se termine dans le terminal et le navigateur comme avec `a`. L'onglet Drive connecte le PC, coupe ou remet la synchro automatique, lance une synchro et reprend les cases de la touche `p`, avec un bouton par PC relié au-dessus de la liste. Les skills s'y rangent en grille, sur autant de colonnes que la largeur le permet, sous un champ qui les filtre par nom. Dans chaque groupe, les cases décochées sont rangées sous une ligne "Décochés (N)", repliée au départ : un clic l'ouvre, et elle reste ouverte tant que la page n'est pas rechargée. Le filtre l'ouvre aussi quand elle contient un skill qui correspond. Sur un autre PC, une case envoie une demande comme dans la page `p` (voir "Régler un autre PC"). Le bouton "Supprimer partout", une croix dans la grille des skills, fait comme Suppr dans cette page, et une ligne en attente d'effacement propose "Annuler l'effacement".

L'onglet Affichage choisit les couleurs et les animations du menu sur ce PC, comme `clm --palette` et `clm --anim`. L'onglet Sauvegardes sauvegarde les comptes cochés dans Téléchargements, liste les archives de ce dossier et en restaure une, avec les mêmes avertissements que la touche `r`.

Les boutons ne répondent que lorsque le menu est affiché. Pendant une page du terminal, une question, une connexion ou le démarrage de clm, la page le dit et attend son retour. Quand `clm` se ferme ou lance un compte, la page devient blanche, et la recharger ensuite affiche l'erreur du navigateur, puisque plus rien n'écoute. Après une mise à jour de clm, le menu redémarre et ouvre un nouvel onglet à la nouvelle adresse, l'ancien reste blanc.

## Mise à jour de clm

Avant d'ouvrir le menu, avant un lancement direct comme `clm -2` et avant `--restore`, `clm` demande à GitHub la dernière release publiée, jamais la branche `main`. Une release porte un tag `v<numéro>`, "v40" par exemple. Quand ce numéro dépasse celui de la version installée, `clm` télécharge en HTTPS `clm-v40.zip` et `clm-v40.zip.sha256`, calcule lui-même l'empreinte SHA-256 de l'archive et refuse d'installer si elle diffère, avec "empreinte du paquet clm invalide, installation refusee". L'archive est ouverte dans un dossier temporaire neuf, réservé à l'utilisateur, puis `clm` lance son `install.ps1` avec le chemin complet de Windows PowerShell (`%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe`), ou son `install.sh` avec `/bin/sh` ailleurs, et redémarre avec les mêmes arguments.

La version installée est rangée dans `clm.version`, à côté des scripts, sous la forme `<commit> <date unix> <numéro>`. Le numéro s'affiche dans l'en-tête du menu, "clm v34". Une release l'apporte dans son archive. Depuis un clone git, l'installeur l'écrit lui-même avec le nombre de commits jusqu'à cette version, et l'efface quand il n'a ni git ni fichier fourni. Sans `clm.version`, ou avec un fichier écrit avant l'arrivée du numéro, la version est inconnue et `clm` ne se met plus à jour seul : il le dit, "version de clm inconnue, pas de mise a jour automatique", avec l'adresse des releases, d'où télécharger la dernière archive pour lancer son installeur à la main.

Les releases sont construites par `.github/workflows/release.yml` quand un tag `v<numéro>` est poussé : la CI tourne d'abord sur les trois systèmes, puis l'archive (`bin`, les installeurs, `LICENSE` et `clm.version`) et son empreinte sont publiées.

Dans le menu, cette étape est la barre "clm", la première au-dessus des comptes. Elle indique "recherche d'une nouvelle version", puis "installation <version>" quand une version plus récente est publiée. Après une installation, `clm` ferme le menu et redémarre. Echap ou Ctrl+C pendant la recherche ferme `clm` sans rien installer ; pendant l'installation, il la laisse finir avant de fermer. Cette barre n'apparaît que si `clm` tourne depuis `.local/bin`.

GitHub a quatre secondes pour répondre. Sans réseau, ou quand l'API limite les appels, le menu s'ouvre avec la version installée, sans message. Un échec pendant l'installation n'empêche pas le menu de s'ouvrir : il s'affiche en bas du menu en couleur d'alerte, devant le résultat de la mise à jour de Claude Code, ou en jaune hors du menu. Une version installée plus récente que la dernière release, après un `install.ps1` depuis un clone, n'est pas remplacée. `clm` ne se met à jour que s'il tourne depuis `.local/bin` : lancé depuis le clone, il ne touche à rien. `--no-update` saute l'étape, `--usage` et `--save` aussi.

Le menu ouvert redemande à GitHub la dernière release toutes les dix minutes, en arrière-plan. Quand une version plus récente est sortie, le bouton "[maj dispo]" apparaît dans l'en-tête. Un clic dessus, ou la touche `u`, ferme le menu, installe la nouvelle version comme au lancement, puis rouvre `clm`. Si l'installation échoue, le message reste affiché trois secondes avant que le menu revienne. Cette vérification n'a lieu que si `clm` tourne depuis `.local/bin`.

Chaque sauvegarde emporte `clm.version`. La restauration refuse une archive faite avec un `clm` plus récent que celui installé, ou quand la version installée est inconnue, avec "sauvegarde faite avec clm ..." et la marche à suivre : relancer `clm`, qui se met à jour, puis restaurer, ou, pour une version inconnue, réinstaller `clm` depuis la dernière release. Une archive faite avant l'arrivée de `clm.version` se restaure sans contrôle.

## Mise à jour de Claude Code

À l'ouverture du menu, et avant un lancement direct comme `clm -2`, `clm` lance `claude update` avec l'environnement du premier compte. Tous les comptes partagent le même exécutable, donc la mise à jour ne tourne qu'une fois. Dans le menu, elle est la barre "Claude Code", qui démarre une fois clm vérifié, en même temps que la barre "Drive". Son résultat reste ensuite en bas du menu jusqu'à l'action suivante. Hors menu, il s'affiche en face de chaque compte.

Avant la vérification de clm, le menu ne montre pas les comptes et répond "comptes affiches apres la verification de clm". Ensuite, les flèches, le clic et `y` marchent tout de suite. Entrée ou un chiffre retient le compte, affiche "compte1 lance a la fin des mises a jour..." et le lance dès que Claude Code et Drive ont fini. Les autres touches répondent "disponible a la fin des mises a jour". Une étape en échec ne bloque pas si internet répond. Sans réseau, `clm` refuse de s'ouvrir, et une étape qui échoue faute de réseau le ferme. `clm -2` et la vue texte font les mêmes étapes en texte, synchro Drive comprise, avant de lancer le compte. Echap ou Ctrl+C laisse finir la mise à jour de clm ou de Claude Code en cours, arrête la synchro Drive, puis ferme `clm`.

Pendant l'étape, la barre suit l'avancement : elle se remplit, ou scintille quand le pourcentage est inconnu. Elle indique "recherche de mise a jour" tant que `claude update` n'a rien annoncé, puis "mise a jour <version>" avec un témoin d'attente et la dernière ligne écrite par `claude update`. Pour une installation native, `clm` surveille le fichier en cours de téléchargement : la ligne passe à "telechargement <version>" avec le pourcentage et les mégaoctets reçus, puis à "installation <version>" à 100 %. La taille attendue est lue dans le manifeste publié par Anthropic, et sans elle seuls les mégaoctets s'affichent. Une installation par paquet (npm) reste sur "mise a jour <version>" jusqu'à la fin.

Le résultat est l'un de ces messages :

- "Claude Code mis a jour, X -> Y" ;
- "Claude Code a jour (X)" ;
- "Claude Code X disponible, a installer avec ..." quand Claude Code est géré par un gestionnaire de paquets comme Homebrew : `clm` ne l'installe pas lui-même ;
- "mise a jour de Claude Code : verification impossible" : `claude update` n'a rien annoncé en 20 secondes ;
- "mise a jour de Claude Code abandonnee, telechargement bloque" : le fichier téléchargé n'a pas grossi depuis 90 secondes ;
- "mise a jour de Claude Code deja en cours ailleurs (PID N)" : une autre session met déjà Claude Code à jour et n'a pas fini au bout d'une minute ;
- "echec de la mise a jour : ..." avec la raison donnée par `claude update`, ou "echec de claude update (code N)" ;
- "Claude Code introuvable, pas de mise a jour" ;
- "claude update : ..." avec sa dernière ligne, ou "claude update termine", quand sa sortie n'a pas été reconnue.

Les échecs s'affichent en rouge et une mise à jour faite en vert.

Avant de conclure à un échec, `clm` réessaie. Quand une autre session tient le verrou de mise à jour, la barre affiche "attente d'une autre session (PID N)" et `claude update` est relancé toutes les 5 secondes pendant une minute. Après un autre échec, `clm` fait jusqu'à trois essais en tout, à deux secondes d'écart, et la barre affiche "nouvel essai (2/3)". Echap arrête ces nouveaux essais. Quand `claude update` refuse une version trop ancienne et garde celle qui est installée, le résultat est "Claude Code a jour (X)".

Un téléchargement complet n'est jamais interrompu. `claude update` tourne en priorité basse, et son arbre de processus est arrêté en cas d'abandon. `--no-update`, `--usage`, `--save` et `--restore` sautent l'étape.

## Sauvegarde et restauration

### Ce que contient une sauvegarde

La touche `s` ouvre une page où tous les comptes sont cochés. Espace coche ou décoche le compte sous le curseur, `t` inverse tout (tout cocher si un compte manque, sinon tout décocher), Entrée valide s'il reste au moins un compte coché, Échap annule.

L'archive reprend l'arborescence du dossier personnel. Elle contient :

- le dossier de chaque compte coché : jetons (hors macOS), réglages, plugins, MCP, historique des conversations ;
- `.claude.json` et `.mcp.json` quand `.claude` est coché ;
- la liste des comptes, à la racine sous son ancien nom, `.claude-accounts.json`, comme dans les archives des versions précédentes ;
- les scripts du menu présents dans `~/.local/bin`.

Sont exclus, à toute profondeur, les dossiers et fichiers nommés `cache`, `paste-cache`, `session-env`, `shell-snapshots`, `ide` et `*.lock`, et les `.exe` de `.local/bin`. Les conversations (`projects/*.jsonl`, avec leurs dossiers `subagents` et `tool-results`) ne sont pas sauvegardées : elles pèsent l'essentiel du dossier. Les mémoires de `projects/*/memory` le sont. Le dossier `plugins/cache`, où Claude Code range le code des plugins installés, en fait partie : la liste des plugins est sauvegardée, leur code téléchargé ne l'est pas. Un dossier masqué rangé directement dans `skills`, c'est-à-dire dont le nom commence par un point comme `skills/.trash`, est ignoré partout : ni sauvegardé, ni synchronisé, ni proposé comme skill. Ceux qui se trouvent plus bas, dans un skill ou un plugin, restent pris.

L'archive s'appelle `claude-comptes-<date>-<heure>`. C'est un `.zip` sous Windows et macOS, et sous Linux quand `bsdtar` est installé (paquet `libarchive-tools`). Avec le seul GNU tar, Linux écrit un `.tar.gz` et ne sait pas relire un `.zip` venu d'un autre poste. Elle va dans le dossier Téléchargements : celui déclaré dans Windows (même déplacé), celui de `XDG_DOWNLOAD_DIR` sous Linux, à défaut `~/Downloads`, créé s'il manque. Une barre suit l'écriture. Des avertissements signalent des fichiers ignorés, souvent parce qu'une session Claude Code les tient ouverts.

L'archive n'est pas chiffrée et contient les jetons de connexion, sauf sous macOS où ils restent dans le trousseau : quiconque la récupère peut se servir des comptes. Ces jetons ne restent valables que jusqu'au prochain renouvellement : le serveur remplace le refresh token à chaque fois et invalide l'ancien. Un compte utilisé depuis la sauvegarde, par Claude Code ou par le menu qui lit ses quotas, demandera donc un `/login` une fois restauré, et la page de restauration le rappelle.

### Restaurer

La touche `r` liste les 9 sauvegardes `claude-comptes-*` les plus récentes du dossier Téléchargements, avec leur date et leur taille. Les flèches et Entrée, ou un chiffre, choisissent l'archive, Échap ou `q` revient au menu. La page suivante coche les comptes présents dans l'archive, avec les mêmes touches que pour la sauvegarde. Il faut ensuite confirmer par `o`.

La restauration fait trois choses :

1. Elle copie l'état actuel des comptes visés déjà présents sur le poste dans une archive `claude-comptes-avant-restauration-*`. Un compte qui n'existe pas encore n'a rien à copier.
2. Elle extrait les dossiers des comptes choisis, plus `.claude.json` et `.mcp.json` si `.claude` en fait partie. Les fichiers de l'archive remplacent ceux du poste, et les fichiers du poste absents de l'archive restent en place. La liste des comptes et les scripts de l'archive ne sont pas extraits. Le `settings.json` de chaque compte garde l'entrée `statusLine` du poste, qui désigne le programme de la barre d'état sur ce PC, ou celle de `.claude` pour un compte qui n'y existait pas encore, et la commande du hook de la barre d'état y prend la forme du système du poste.
3. Elle ajoute à la liste des comptes ceux qui n'y étaient pas, sous le nom qu'ils avaient dans l'archive, puis recrée les liens partagés de tous les comptes.

Une archive placée ailleurs se restaure par `clm --restore=<chemin>`.

### Dossiers partagés

Les comptes secondaires partagent avec `.claude` les dossiers `agents`, `commands`, `hooks`, `plugins`, `rules` et `skills`, par des jonctions sous Windows et des liens symboliques ailleurs, et les fichiers `ANTI-EMPREINTE.md`, `CLAUDE.md`, `settings.local.json` et `statusline.json` par des liens physiques. Ces liens sont créés à l'ajout d'un compte, après une restauration et à chaque lancement d'un compte, seulement pour les éléments qui existent dans `.claude`. Un vrai dossier déjà présent à la place d'un lien est renommé en `<nom>.bak-sync` avant d'être relié, et laissé tel quel si le renommage échoue. Claude Code remplace parfois un fichier au lieu de le réécrire, ce qui casse le lien physique : la copie la plus récente est alors gardée et le lien recréé. Les éléments partagés ne sont sauvegardés qu'une fois, avec `.claude`.

### Réglages et MCP synchronisés

Chaque compte garde son `settings.json` et son `.claude.json`, mais `clm` les synchronise à chaque lancement d'un compte. Dans `settings.json`, tout est commun sauf `model`, `modelSettings` et `theme`, propres à chaque compte. Dans `.claude.json`, seul `mcpServers` est commun : connexion, projets et le reste ne bougent pas. Ce sont les MCP globaux du PC, qui ne partent jamais sur le Drive (voir "Réglages de synchro par PC").

La règle est celle du dernier modifié. `clm/sync-state.json` garde la dernière valeur commune. Parmi les comptes qui s'en écartent, celui dont le fichier est le plus récent gagne, et sa valeur est recopiée dans les autres. Avant sa première réécriture par la synchronisation, un fichier est copié en `<fichier>.bak-sync`. Un verrou, `clm/sync.lock`, empêche deux lancements de synchroniser en même temps : au bout de 5 secondes d'attente, le second lance le compte sans synchroniser et l'indique.

Juste avant de lancer un compte, `clm` vérifie deux réglages dont l'absence fait reposer à Claude Code ses questions d'accueil, choix du thème compris. Le `.claude.json` du compte doit marquer l'accueil comme fait : `clm` y écrit `hasCompletedOnboarding` s'il manque, et crée le fichier s'il n'existe pas ou s'il est vide. Le `settings.json` doit porter un `theme` : à défaut, `clm` y met celui d'un autre compte, ou `dark` si aucun n'en a.

## Synchronisation entre PC

`clm` peut garder les mêmes comptes sur plusieurs PC, Windows, macOS et Linux mélangés, en passant par un dossier `clm-sync` de Google Drive. Tout ce qu'une sauvegarde emporte y passe, jetons de connexion compris, sauf les scripts de `clm` : chaque PC se met à jour seul depuis GitHub.

### Connecter un PC

Dans le menu, la touche `y` connecte le PC tant qu'il ne l'est pas : le navigateur s'ouvre sur la page Google qui demande l'accès au Drive, il suffit d'autoriser, puis une première synchro démarre. `clm --drive-login` fait la même connexion en ligne de commande. Si le navigateur ne s'ouvre pas, le lien est affiché, et la réponse est attendue 5 minutes. La connexion est rangée dans `clm/drive.json`, lisible par son seul propriétaire hors Windows, avec le nom du PC, celui de la machine.

`clm` passe par sa propre application Google, `clm`, de type application de bureau, déjà en production : rien à créer dans la console Google Cloud. La portée demandée, `drive.file`, ne donne accès qu'aux fichiers créés par `clm`. Le secret d'une application de bureau n'en est pas un pour Google, il est donc écrit dans `bin/claude-drive-auth.ps1`. Pour passer par une autre application, mettre `clientId` et `clientSecret` dans `clm/drive.json` avant de se connecter.

### Phrase de synchro

Tout ce que `clm` dépose sur le Drive est chiffré par une phrase de synchro, la même sur tous les PC, qui ne quitte jamais le PC. Après la connexion, `clm` la demande deux fois, masquée, 12 caractères au moins. Sur un Drive neuf, elle est créée. Sur un Drive déjà utilisé, elle est vérifiée avant d'être gardée. `clm --sync-key` fait la même saisie. Chaque PC la garde sous une forme dérivée : protégée par Windows dans `clm/sync-key`, dans le trousseau sous macOS, dans `clm/sync-key` lisible par son seul propriétaire sous Linux. Le Drive garde à sa racine `clm-key.json`, qui permet de vérifier la phrase sans la révéler.

Chaque fichier est chiffré (AES-256) et signé avec son chemin, ce qui fait refuser un fichier modifié, déplacé ou chiffré avec une autre phrase. Les fichiers synchronisés sont rangés sous des noms en `clm-enc/`, que les anciennes versions de `clm` ne lisent pas. Un fichier refusé, ou laissé en clair par une ancienne version, n'est jamais écrit sur le disque : la synchro le compte en échec et le nomme, "refuses : ...", sans s'arrêter pour autant. Le premier PC à jour qui possède ce fichier le renvoie chiffré, et la copie en clair part à la corbeille quand tous les PC sont à jour. D'ici là, la synchro nomme les PC en retard. Restent lisibles sur le Drive : les noms des fichiers, leurs dates, le nom des PC, l'expiration des jetons et l'adresse e-mail de chaque compte.

Sans phrase sur le PC, rien ne se synchronise. Le menu le signale et `y` la demande. Le veilleur et le hook ne posent jamais de question. `clm --sync-key-reset` change la phrase : ce PC renvoie tout avec la nouvelle, et les autres doivent la saisir. `clm --sync-key-forget` l'efface de ce PC.

Le premier PC envoie tout. Sur un PC qui rejoint, la première synchro prend ce qui est sur le Drive quand un fichier existe des deux côtés : un PC neuf n'écrase pas les comptes des autres avec ses réglages par défaut. L'ancienne version locale est gardée sous `<fichier>.conflit-<PC>`.

### Quand la synchro a lieu

La synchro automatique est active dès la connexion. `clm --sync-auto=off` la coupe et `clm --sync-auto=on` la remet. Quand elle est active :

- le menu lance une synchro en arrière-plan à son ouverture, dès que clm est vérifié, en même temps que la mise à jour de Claude Code. Sa barre "Drive" suit le nombre de fichiers traités, et un compte choisi pendant ce temps part à sa fin. Si une autre synchro tourne déjà sur ce PC, celle de la session précédente par exemple, la barre affiche "attente de la synchro en cours" et réessaie jusqu'à ce qu'elle finisse, une minute au plus. Elle s'arrête quand on quitte le menu. Quitter pendant la vérification de clm ferme `clm` sans la lancer ;
- pendant que Claude Code est ouvert, un veilleur caché synchronise : toutes les 30 secondes si le Drive a changé, et 2 secondes après un changement sur le disque, avec 30 secondes au moins entre deux synchros ;
- à la fermeture de Claude Code, par `/quit`, Ctrl+C ou la fenêtre fermée, la fenêtre rend la main tout de suite et le veilleur fait la dernière synchro.

À la main, la touche `y` du menu, ou un clic sur l'état de la synchro dans l'en-tête, lance une synchro et affiche son résultat. `clm --sync` fait de même en ligne de commande, avec la progression, et sort avec le code 1 en cas d'erreur.

L'en-tête affiche, après la version, "sync 14:32" pour la dernière synchro réussie, "sync 120/5508" pendant un transfert, "sync erreur" en couleur d'alerte, et "sync jamais" avant la première. "sync..." apparaît aussi pendant la synchro du veilleur ou d'une autre fenêtre `clm` du même PC. "sync attente" signale qu'une synchro du menu a trouvé la place prise : elle repart dès que l'autre a fini, ou une minute plus tard. Rien n'apparaît quand le Drive n'est pas connecté.

### Le veilleur

Le veilleur est un process PowerShell sans fenêtre, en priorité basse, lancé par `clm` à l'ouverture de Claude Code quand le PC est connecté au Drive. Il n'y en a qu'un par PC, quel que soit le nombre de fenêtres : chaque session ouverte s'inscrit dans `clm/drive-watch/`, et un verrou, `clm/drive-watch.lock`, garde le veilleur unique. Il s'arrête de lui-même quand plus aucune session n'est ouverte et que la dernière synchro est faite. Quand `clm` est mis à jour pendant qu'il tourne, il s'arrête et repart aussitôt avec la nouvelle version. Un menu ouvert avant la mise à jour garde son ancien code en mémoire, alors ses synchros passent par la version installée.

Il regarde le disque par les notifications du système, sans relire les dossiers. Là où elles manquent, il synchronise toutes les minutes. Les jetons de connexion sont comparés à chaque passage, même quand la synchro automatique est coupée. Le `.claude.json` d'un compte ouvert, que Claude Code réécrit sans arrêt, attend la fin de la session pour partir.

Une session dont le process a disparu, fenêtre fermée ou PC éteint, compte comme finie. Une synchro qui échoue est retentée une minute plus tard, et le veilleur renonce au bout de 10 minutes d'échecs : la synchro suivante reprend le travail. S'il ne peut pas démarrer, la fenêtre fait elle-même la synchro de sortie, 30 secondes au plus, comme avant. Son journal est `clm/drive-watch/watch.log`, vidé au-delà de 256 Ko.

Une synchro coupée en route ne perd pas son travail. Son état est enregistré toutes les minutes pendant les transferts, et la suivante ne refait pas ce qui était déjà passé. Quitter le menu pendant l'analyse du disque l'arrête aussitôt, avec le message "interrompue pendant l'analyse, reprise a la prochaine synchro".

### Ce qui est comparé

Chaque PC garde dans `clm/drive-state.json` l'état de sa dernière synchro, et compare à cet état le disque et le Drive. Un fichier modifié d'un seul côté est copié de l'autre, une suppression est propagée. Un fichier modifié des deux côtés est un conflit : la version la plus récente gagne et l'autre reste sur ce PC sous `<fichier>.conflit-<PC>`. Les fichiers `.conflit-*`, `.bak-sync` et `.tmp` ne sont pas synchronisés, et les exclusions de la sauvegarde s'appliquent. Quatre sortes de fichiers restent propres à chaque PC et ne passent par le Drive dans aucun sens : les conversations (voir plus bas), les dossiers `file-history` et `node_modules`, et les profils Chrome rangés sous `chrome-bidi/profils`. Le ménage suit les règles : quand une version de `clm` exclut de nouveaux fichiers, comme ces quatre sortes ou les dossiers masqués de `skills`, chaque PC met à la corbeille du Drive, en lots de 100, ceux qu'il y avait envoyés et que les règles écartent désormais. Il le fait à la première synchro complète qui suit le passage de tous les PC à cette version, et ne touche pas à ceux des autres PC, que chacun retire à son tour. Un skill décoché sur un PC n'est pas concerné : il reste sur le Drive pour les autres. Ceux qui ne portent le nom d'aucun PC, envoyés par une très ancienne version, partent avec ceux du premier PC qui passe. La base de chaque PC les oublie, et rien n'est effacé sur les disques.

Pour aller vite, la liste du Drive n'est relue en entier qu'une fois par jour. Entre deux, `clm` ne demande au Drive que ce qui a changé depuis la dernière synchro, et garde la liste dans `clm/drive-remote.json`. Les téléchargements et les petits envois partent en avance sur 4 connexions en parallèle, puis les fichiers sont posés sur le disque et notés dans la base dans l'ordre.

Plus de 20 suppressions prévues, ou plus d'un dixième des fichiers connus, bloquent la synchro avec "synchro bloquee : N suppressions prevues". Après vérification, `clm --sync --force` passe outre. Un fichier qui échoue est retenté à la synchro suivante, et trois échecs de suite arrêtent la synchro en cours. Un verrou, `clm/drive.lock`, empêche deux synchros en même temps sur un PC.

Le `settings.json` de chaque compte garde deux réglages propres au PC. Son entrée `statusLine`, qui désigne le programme de la barre d'état sur ce PC, ne part pas sur le Drive : à la réception, `clm` remet celle que le PC avait déjà, ou à défaut celle de `.claude`. La commande du hook de la barre d'état part sous la forme de Windows, et chaque PC la reçoit sous la forme de son système. Un PC où la barre n'a pas encore été installée reçoit donc des réglages sans barre d'état : y lancer l'installeur de la [barre d'état](https://github.com/LetermeFlorent/claude-statusline). Un `settings.json` envoyé par un ancien `clm`, `statusLine` compris, est nettoyé à la réception puis renvoyé une fois sous la forme commune.

Les conversations ne quittent jamais leur PC : les fichiers `.jsonl` de `projects/` et les dossiers `subagents` et `tool-results` qui les accompagnent restent hors du Drive. La mémoire des projets, `projects/<projet>/memory`, passe, elle. Comme Claude Code nomme ces dossiers d'après le chemin du projet, la mémoire d'un projet ouvert sous Windows reste à part sous macOS.

### Réglages de synchro par PC

La touche `p` ouvre "Reglages de synchro de ce PC", une liste à cocher en deux groupes : les skills, puis les MCP. À droite de chaque MCP, son origine : "perso" pour ceux de `~/.mcp.json`, le dernier dossier du chemin de son projet sinon, suivis de son système, ou "ce PC" pour un MCP global. Une case cochée veut dire que l'élément est synchronisé sur ce PC. Les flèches déplacent le curseur, Espace coche ou décoche, Suppr efface partout après confirmation par `o`, et Échap ou `q` revient au menu, en lançant une synchro si une case a changé. La page demande un Drive connecté.

En tête de chaque groupe, la case "tous les skills" ou "tous les MCP" vaut pour tout le groupe, MCP globaux compris. À droite, elles comptent les cases cochées, et un carré gris dit que le groupe l'est en partie. Espace sur l'une d'elles décoche tout le groupe s'il était entièrement coché, et le coche en entier sinon. Une ligne en attente d'effacement n'est pas comptée et garde son effacement. Suppr n'y fait rien : un effacement se demande ligne par ligne.

Un MCP local est déclaré pour un projet situé sous le dossier perso, dans `projects.<chemin>.mcpServers` du `.claude.json` d'un compte, ou dans `~/.mcp.json`. Chaque PC publie les siens dans son fichier du dossier `presence` du Drive, et `mcpServers` ne part plus dans les `.claude.json` envoyés : chaque PC reconstruit ses fichiers avec ses propres cases. Un MCP global est déclaré dans `mcpServers` en tête du `.claude.json`. Il ne quitte jamais son PC, et `clm` le recopie entre les comptes du PC comme décrit dans "Réglages et MCP synchronisés".

Un nouveau skill arrive coché sur tous les PC. Un nouveau MCP local arrive coché sur les PC du même système que celui qui l'a ajouté, décoché sur les autres, et son système s'affiche à droite de son nom. Décocher un skill retire son dossier de ce PC à la synchro suivante, une fois ses fichiers présents sur le Drive : un skill que ce PC est seul à avoir, ou qu'il vient de modifier, y part d'abord. Les autres PC le gardent. Décoché sur tous les PC, il part à la corbeille du Drive et sa case disparaît, sachant qu'un PC dont `clm` n'est pas à jour compte comme s'il l'avait coché. Décocher un MCP local retire sa définition des fichiers de ce PC, et `claude mcp remove` fait de même sur ce PC seulement. Décocher un global le retire de tous les comptes de ce PC et met sa définition de côté dans `clm/sync-catalog.json`, d'où la recocher le remet. Les fichiers d'un compte dont Claude Code est ouvert attendent sa fermeture.

Suppr efface partout. Un skill part à la corbeille du Drive et son dossier quitte chaque PC, un MCP local quitte chaque PC à sa prochaine synchro, un global quitte tous les comptes de ce PC. D'ici là, la ligne affiche "efface a la prochaine synchro". Seule la définition d'un MCP voyage : le programme qu'elle lance, paquet npm ou exécutable, s'installe à la main sur chaque PC.

Les cases ne valent que lorsque tous les PC du Drive ont une version de `clm` qui les gère. Avant, les MCP partent en entier comme avant, et la page nomme les PC en retard : "MCP envoyes en entier tant que ces PC n'ont pas clm a jour". Les cases décochées et les effacements en attente sont gardés dans `clm/sync-choice.json`.

Sans menu, `clm --prefs` affiche les mêmes cases, `[x]` ou `[ ]`, chacune avec son id : `skill:<nom>`, `mcp:<projet>|<nom>` (projet vide pour `~/.mcp.json`) ou `global:<nom>`. `"skill:*"` vise tous les skills et `"mcp:*"` tous les MCP, globaux compris, entre guillemets à cause du `*`, et `[-]` marque un groupe coché en partie. `--prefs-on` et `--prefs-off` cochent et décochent un ou plusieurs ids, `--prefs-erase` les efface partout et demande `--yes`, mais refuse un groupe entier. Le nom seul suffit quand un seul élément le porte, sinon la commande liste les ids possibles. Après un changement, `clm` lance la synchro, comme Échap dans la page.

### Régler un autre PC

Quand plusieurs PC partagent le Drive, la page `p` les nomme en haut, ce PC d'abord, et les flèches gauche et droite passent de l'un à l'autre. Les cases d'un autre PC montrent ce qu'il synchronise d'après sa dernière synchro. Espace en change une : la demande part sur le Drive à la synchro suivante, et le PC visé l'applique à la sienne, comme si la case avait changé chez lui. D'ici là, la ligne affiche "en attente", et remettre la case à sa valeur retire la demande. La liste d'un autre PC n'a pas de MCP globaux, qui ne quittent jamais leur PC, et Suppr n'y fait rien : effacer partout se fait depuis la page de ce PC.

Quand une même case change sur deux PC, le changement le plus récent gagne, fait sur place ou demandé d'ailleurs. Chaque PC publie dans son fichier du dossier `presence` son système, ses cases, les demandes qu'il adresse aux autres et, pour chaque autre PC, la date de la dernière demande qu'il a prise en compte. Une demande prise en compte, adressée à un PC disparu du Drive ou vieille de plus de 30 jours est retirée. Un PC dont la version de `clm` ne lit pas ces demandes reste dans la liste, sans cases, avec "clm n'est pas a jour sur ce PC".

### Jetons de connexion

Les jetons de chaque compte ont leur propre fichier sur le Drive, et le plus récent gagne toujours : un PC ne remplace pas un jeton local par un jeton qui expire plus tôt. Avant de lancer un compte, `clm` prend le jeton du Drive s'il est plus frais. Avant de renouveler un jeton expiré, il regarde d'abord si un autre PC ne l'a pas déjà fait, et envoie le nouveau jeton après un renouvellement. Pendant que Claude Code est ouvert, le veilleur compare les jetons toutes les 30 secondes et dès que l'un d'eux change sur le disque, et à la fermeture le jeton part sur le Drive, même quand la synchro automatique est coupée. Sous macOS, les jetons sont lus et écrits dans le trousseau, par l'entrée standard de `security` pour que le jeton n'apparaisse jamais dans la liste des process.

Un jeton local illisible, tenu par Claude Code au moment de la synchro, n'est jamais écrasé : le compte est retenté à la synchro suivante. Chaque jeton envoyé porte l'adresse du compte, et un PC refuse le jeton d'une autre adresse, ce qui arrive quand le même dossier de compte sert à deux comptes différents sur deux PC.

Un compte lancé sur un PC est marqué ouvert pendant 12 heures, jusqu'à la fermeture de Claude Code. Les autres PC affichent alors "ouvert sur <PC>" sur sa carte, et `clm` n'y renouvelle pas son jeton tant qu'il est ouvert ailleurs.

## Liste des comptes

Les comptes sont rangés dans `clm/accounts.json` (`%LOCALAPPDATA%\clm\accounts.json` sous Windows), un tableau JSON dans l'ordre du menu :

```json
[
  { "Label": "compte1", "Dir": ".claude" },
  { "Label": "pro", "Dir": ".claude-compte2" }
]
```

`Label` est le nom affiché, `Dir` le dossier, relatif au dossier personnel. Quand ce fichier manque ou est illisible, `clm` le recrée : `.claude` devient `compte1`, puis chaque dossier `.claude-compte2` à `.claude-compte9` présent devient un compte. Ensuite, seul le fichier compte : un dossier créé à la main n'apparaît qu'une fois ajouté au fichier.

## Quotas

Les pourcentages viennent de l'API `api.anthropic.com/api/oauth/usage`, avec le jeton du compte. Il est lu dans `.credentials.json` du dossier du compte, et sous macOS d'abord dans le trousseau, où Claude Code le range. Sous Windows et Linux, un jeton expiré est renouvelé par `clm` lui-même avec le refresh token du compte, comme Claude Code le fait au démarrage, puis `.credentials.json` est réécrit. Le serveur peut remplacer le refresh token à cette occasion : une session Claude Code restée ouverte sur ce compte avec l'ancien peut alors redemander un `/login`. Sous macOS, `clm` ne renouvelle rien, et n'écrit dans le trousseau que les jetons reçus du Drive. Les comptes sont interrogés l'un après l'autre, avec 10 secondes au plus par appel.

Les résultats sont gardés trois minutes dans un cache, partagé par le menu, `--usage` et le hook de la barre d'état : `%LOCALAPPDATA%\claude-menu\usage.json` sous Windows, `~/Library/Caches/claude-menu/usage.json` sous macOS et `${XDG_CACHE_HOME:-~/.cache}/claude-menu/usage.json` sous Linux. L'API limite les appels par jeton, et une relecture trop rapprochée la fait répondre 429 pendant de longues minutes. Après un refus, le compte n'est plus interrogé pendant 1 minute, puis 2, 4, 8 et enfin 10 minutes au plus si les refus se suivent, avec quelques secondes prises au hasard en plus, ou pendant le délai `Retry-After` envoyé par l'API s'il est plus long (une heure au plus). Cette pause est notée dans le cache : une autre fenêtre `clm` ou le hook la respectent aussi. La première lecture réussie la lève. Pendant la pause, le menu affiche les dernières valeurs du cache, avec leur âge. Une fenêtre dont la remise à zéro a eu lieu depuis cette lecture repart à 0 %, sans heure, avec la mention "fenetre passee".

Avant d'appeler l'API, `clm` regarde aussi le fichier d'état de la barre d'état (voir "Barre d'état à jour au lancement"). Quand Claude Code tourne sur un compte, la barre y range les quotas que Claude Code lui transmet, avec l'heure de cette lecture. Si elle est plus récente que le cache et date de moins de trois minutes, ou de moins de 30 secondes pour la touche `m`, `clm` reprend ces chiffres sans appeler l'API. Une pause après un refus de l'API reste celle du cache, même quand les chiffres affichés viennent de la barre.

Un compte sans chiffres affiche l'un de ces messages :

- "non connecte" : pas de jeton pour ce compte ;
- "compte deconnecte, lancer le compte une fois" : le jeton a expiré et n'a pas pu être renouvelé. Le cache n'est pas montré dans ce cas, ses chiffres seraient périmés ;
- "jeton refuse, lancer le compte une fois" : l'API refuse le jeton ;
- "quota inconnu, l'API de suivi refuse les appels (reessai dans ...)" : l'API limite les appels et le cache n'a aucune valeur pour ce compte ;
- "API de suivi injoignable" : pas de réseau, ou une autre erreur.

## Couleurs claires ou sombres

Le menu choisit sa palette au démarrage, dans cet ordre :

1. la variable `STATUSLINE_BG` (`light`, `clair`, `dark` ou `sombre`) ;
2. le choix de ce PC, posé par `clm --palette dark` ou `light`, ou par la page web, et gardé dans `clm/display.json` ;
3. le thème du système : sous Windows le réglage des applications, sous macOS l'apparence (`defaults read -g AppleInterfaceStyle`), sous Linux `gsettings` (`color-scheme`), puis `GTK_THEME`, puis les couleurs de KDE (`kdeglobals`).

À défaut, la palette sombre s'applique. `clm` ne lit ni `~/.claude/statusline.json` ni le programme de la [barre d'état](https://github.com/LetermeFlorent/claude-statusline) : ses couleurs sont celles de la barre, recopiées dans le menu.

Menu ouvert, `clm` relit le thème du système toutes les deux secondes et passe d'une palette à l'autre en fondu quand il change, fond compris. `STATUSLINE_BG` ou un choix `dark` ou `light` fixe la palette et coupe ce suivi, `clm --palette auto` le rétablit.

## Barre d'état à jour au lancement

Quand `clm` lance un compte, il écrit d'abord les quotas 5 h et 7 j de ce compte dans le fichier d'état de la [barre d'état](https://github.com/LetermeFlorent/claude-statusline), de sorte que les valeurs sont justes dès le premier affichage. Ce fichier est `%LOCALAPPDATA%\claude-statusline\state` sous Windows, `~/Library/Application Support/claude-statusline/state` sous macOS et `${XDG_STATE_HOME:-~/.local/state}/claude-statusline/state` sous Linux. Rien n'est écrit si son dossier n'existe pas, c'est-à-dire si la barre n'a jamais tourné, ni si les quotas du compte ne sont pas lisibles.

Chaque compte y a ses propres clés, suffixées par le nom de son dossier : `q5_at@claude-compte2` (heure de remise à zéro), `q5_pct@claude-compte2` (pourcentage), de même pour `q7_`, et `q_at@claude-compte2` (heure de lecture de ces quotas, qui recule de leur âge quand ils viennent du cache). Le script ne réécrit que les clés du compte lancé, retire les anciennes clés sans suffixe, et garde le reste du fichier.

Pour le même effet avec un simple `claude`, l'installeur ajoute un hook `SessionStart` (déclencheur `startup`, délai 15 secondes) dans le `settings.json` de `.claude` et de chaque `.claude-compte*` qui en a un. Sa commande est `powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME/.local/bin/claude-statusline-seed.ps1"` sous Windows et `pwsh -NoProfile -File "$HOME/.local/bin/claude-statusline-seed.ps1"` ailleurs. Claude Code la passe à un shell, `sh` sous Linux et macOS, Git Bash ou à défaut PowerShell sous Windows, qui remplace `$HOME` par le dossier personnel du PC. Les dossiers sont trouvés par leur nom, sans lire la liste des comptes, et un compte ajouté plus tard par `a` reçoit le hook avec la copie du `settings.json` de `.claude`. Un fichier qui contient déjà le hook n'est pas touché. Les autres sont d'abord copiés en `settings.json.bak-seed`. Une commande périmée, comme un chemin complet venu d'un autre PC, y est remplacée par celle du PC sans rien changer d'autre. Un fichier sans hook est réécrit par PowerShell : les valeurs restent, la mise en forme change. Chaque mise à jour de `clm` relance l'installeur, et donc cette vérification. Ce hook lance `claude-statusline-seed.ps1`, qui reconnaît le compte par `CLAUDE_CONFIG_DIR` et ne fait rien pour un dossier absent de la liste des comptes. Si le compte n'a aucune fenêtre de 5 h ouverte, la barre garde `--%` sur 5 h jusqu'au premier message.

## Fichiers et variables

Les fichiers propres à `clm` vivent dans un dossier par utilisateur, noté `clm/` dans ce README : `%LOCALAPPDATA%\clm` sous Windows, `$XDG_STATE_HOME/clm` sous Linux, ou `~/.local/state/clm` quand cette variable manque, et `~/Library/Application Support/clm` sous macOS. Les versions précédentes les rangeaient dans le dossier personnel, sous des noms en `.claude-` ou `.clm-`. Le menu, le veilleur et le hook les déplacent au démarrage, une fois pour toutes : un fichier présent aux deux endroits garde sa version du dossier `clm/`, et l'ancien est supprimé. Tant qu'un autre `clm` tourne encore sur le PC, menu, veilleur ou hook, rien ne bouge et le déplacement attend le lancement suivant. Entre-temps, et si un déplacement échoue, chaque fichier est lu là où il se trouve. Sur le Drive et dans les sauvegardes, la liste des comptes garde son nom `.claude-accounts.json`.

`clm` écrit ou modifie ces fichiers :

| Fichier | Rôle |
|---|---|
| `~/.local/bin/clm`, `clm.cmd`, `claude-menu.cmd`, `claude-*.ps1` | le menu, copié par l'installeur |
| `~/.local/bin/clm-web/` | la page web, copiée par l'installeur |
| `clm/accounts.json` | liste des comptes |
| `clm/accounts.json.bad` | copie d'une liste illisible, mise de côté avant d'être recréée |
| `~/.claude-compteN/` | dossiers des comptes ajoutés |
| `settings.json` de chaque compte, et sa copie `settings.json.bak-seed` | hook `SessionStart`, ajouté ou corrigé par l'installeur |
| cache `claude-menu/usage.json` | derniers quotas lus et pauses après un refus de l'API |
| `claude-menu/clm-conin-*.dll`, sous Windows | lecteur de la souris, compilé une fois |
| `.credentials.json` de chaque compte, hors macOS | jeton renouvelé quand il a expiré |
| fichier d'état `claude-statusline/state` | quotas pour la barre d'état |
| `claude-comptes-*.zip` ou `.tar.gz` dans Téléchargements | sauvegardes |
| `clm/display.json` | couleurs et animations choisies pour ce PC |
| `clm/drive.json` | connexion Google Drive, nom du PC, synchro automatique |
| `clm/sync-key`, ou le trousseau sous macOS | phrase de synchro de ce PC, sous forme dérivée |
| `clm/drive-state.json` et `clm/drive*.lock` | état de la dernière synchro Drive, verrous de la synchro, des dossiers Drive, des jetons et du veilleur |
| `clm/drive-remote.json` | liste du Drive gardée entre deux synchros |
| `clm/sync-choice.json` et `clm/sync-choice.lock` | cases décochées de la page `p`, effacements en attente, demandes aux autres PC, et leur verrou |
| `clm/sync-catalog.json` | MCP et cases connus des autres PC, MCP globaux mis de côté |
| `clm/drive-watch/` | sessions Claude Code ouvertes et journal du veilleur |
| `clm/sync-state.json` et `clm/sync.lock` | dernières valeurs communes des réglages partagés entre comptes, et leur verrou |
| `<fichier>.conflit-<PC>` | version perdante d'un conflit de synchro |

Il lit `USERPROFILE` puis `HOME` pour le dossier personnel, `LOCALAPPDATA` sous Windows, `XDG_CACHE_HOME`, `XDG_STATE_HOME` et `XDG_CONFIG_HOME` sous Linux, `STATUSLINE_BG` et `GTK_THEME` pour les couleurs, `CLM_ANIM` pour les animations, et `CLAUDE_CONFIG_DIR` dans le hook. Il pose ou retire lui-même `CLAUDE_CONFIG_DIR` pour lancer un compte.

## Tests

`tests/run.ps1` vérifie les fonctions sans réseau ni vrai compte, dans un dossier temporaire, et sort avec un code non nul en cas d'échec. Il charge tous les fichiers `*.checks.ps1`, rangés par domaine dans `accounts`, `machine`, `menu`, `setup`, `sync`, `ui`, `usage` et `web`. Ceux de `sync`, comme `machine/drive.checks.ps1`, simulent Google Drive en mémoire et deux PC dans des dossiers temporaires. Il tourne avec `powershell -File tests\run.ps1` comme avec `pwsh -File tests/run.ps1`. Le calcul du suffixe de compte du fichier d'état a en plus un test Pester, `tests/StateTag.Tests.ps1`.

La CI lance ces tests à chaque envoi sur `main` et sur chaque pull request, sous Linux, macOS et Windows, avec PowerShell 7 partout et Windows PowerShell 5.1 en plus sous Windows. Elle vérifie aussi la syntaxe de `bin/clm` et de `install.sh`.

## Limites

Les touches `1` à `9` et `-1` à `-9` ne couvrent que les neuf premiers comptes. La page de restauration ne propose que les neuf sauvegardes les plus récentes. Les quotas viennent d'une API non documentée d'Anthropic, qui peut changer ou limiter les appels. Le renouvellement des jetons passe lui aussi par un point d'accès OAuth non documenté : s'il change, le compte s'affiche "compte deconnecte". Ce point d'accès refuse les appels qui ne se présentent pas comme Claude Code : `clm` envoie donc le même en-tête `User-Agent` que lui, avec la version de Claude Code installée. Sous macOS, les sauvegardes ne contiennent pas les jetons de connexion. Un même compte ouvert en même temps sur deux PC peut finir déconnecté sur l'un des deux, puisque chaque Claude Code renouvelle son jeton de son côté et que le serveur invalide l'ancien : le menu prévient par "ouvert sur <PC>" sans l'empêcher.
