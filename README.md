# claude-account-menu

Menu en terminal pour jongler entre plusieurs comptes Claude Code sur un même poste Windows. Chaque compte vit dans son propre dossier de configuration (`.claude`, `.claude-compte2`, etc.), et `clm` lance Claude Code sur celui qu'on choisit, avec le quota 5 h et 7 j de chacun affiché à côté.

## Installation

Il faut Windows 10 1803 ou plus récent (pour `tar.exe`), PowerShell 5.1, et Claude Code déjà installé.

```powershell
git clone https://github.com/LetermeFlorent/claude-account-menu.git
cd claude-account-menu
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Le script copie les fichiers de `bin` dans `%USERPROFILE%\.local\bin` et ajoute ce dossier au PATH utilisateur si besoin. Ouvrir ensuite un nouveau terminal et taper `clm`.

## Touches du menu

Les flèches et Entrée lancent le compte sélectionné, les chiffres 1 à 9 lancent directement le compte correspondant. Le reste :

- `a` ajoute un compte : nom, création du dossier, puis connexion dans le navigateur
- `s` sauvegarde les comptes cochés dans un zip, dans le dossier Téléchargements
- `r` restaure tout ou partie d'un zip de sauvegarde
- `q` ou Échap quitte

À l'ajout d'un compte, si claude.ai est déjà connecté dans le navigateur sur un autre compte, c'est cet autre compte qui sera enregistré. Ouvrir le lien de connexion dans une fenêtre privée évite le piège.

## Ligne de commande

```
clm -2                       lance le compte 2
clm -2 --resume              les arguments restants passent à Claude Code
clm --usage                  quotas de tous les comptes
clm --save                   sauvegarde complète
clm --save=compte2,compte3   sauvegarde de certains comptes
clm --restore=<zip> --only=compte2
```

## Ce que contient une sauvegarde

Le zip reprend l'arborescence du dossier utilisateur : le dossier de chaque compte coché (jetons, réglages, skills, plugins, MCP, historique des conversations), `.claude.json` et `.mcp.json` avec le premier compte, la liste des comptes et les scripts du menu. Les caches et fichiers de session sont exclus.

Les comptes secondaires partagent les dossiers `agents`, `commands`, `hooks`, `rules` et `skills` du premier compte par des jonctions, et quelques fichiers (`CLAUDE.md`, `settings.local.json`, `statusline.json`) par des liens physiques. Ces éléments partagés ne sont sauvegardés qu'une fois, avec le premier compte, et les liens sont recréés à la restauration.

Avant toute restauration, l'état actuel des comptes visés est copié dans un zip `claude-comptes-avant-restauration-*`.

Le zip n'est pas chiffré et contient les jetons de connexion : quiconque le récupère peut se servir des comptes.

## Quotas

Les pourcentages viennent de l'API `api.anthropic.com/api/oauth/usage`, qui limite elle-même le nombre d'appels. Les résultats sont gardés deux minutes dans `%LOCALAPPDATA%\claude-menu\usage.json`, et le menu affiche les dernières valeurs connues quand l'API refuse.
