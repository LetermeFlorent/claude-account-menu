# Synchronisation des comptes entre PC par Google Drive

## Objectif

Retrouver sur chaque PC (Windows, Mac, Linux) l'état complet des comptes Claude Code gérés par
clm : configuration, liste des comptes, conversations et mémoire, et jetons de connexion, sans
qu'un PC déconnecte l'autre. La synchro est automatique par défaut et peut aussi se lancer à la
main.

La version de clm n'entre pas dans la synchro : l'auto-update depuis GitHub s'en charge déjà au
lancement.

## Décisions prises avec Florent

| Sujet | Choix |
|---|---|
| Contenu | tout, jetons compris |
| Transport | API Google Drive appelée directement par clm |
| Déclenchement | auto par défaut, manuel en plus |
| OS | mélange Windows, Mac, Linux |
| Fusion de la mémoire d'un projet entre OS | hors v1, piste v2 par URL git du projet |

## Connexion au Drive

Une fois par PC, `clm --drive-login` :

1. demande le client ID et le secret OAuth s'ils ne sont pas déjà connus ;
2. ouvre le navigateur par défaut sur la page de consentement Google, avec PKCE et une
   redirection vers `http://127.0.0.1:<port libre>` ;
3. reçoit le code sur ce port, l'échange contre un jeton d'accès et un jeton de renouvellement ;
4. écrit le tout dans `~/.clm-drive.json`, fichier local jamais synchronisé.

La portée demandée est `https://www.googleapis.com/auth/drive.file` : clm ne voit que les
fichiers qu'il a créés. Cette portée n'est pas sensible, l'app peut donc passer en production
sans vérification Google, ce qui évite l'expiration à 7 jours des jetons d'une app en test.

Préalable côté Florent, documenté dans le README : créer un projet Google Cloud, activer l'API
Drive, créer un identifiant OAuth de type application de bureau, passer l'écran de consentement
en production.

`~/.clm-drive.json` contient aussi le nom du PC (nom d'hôte par défaut) et le réglage `auto`
(`true` par défaut, modifié par `clm --sync-auto=on|off`).

## Stockage sur le Drive

```
clm-sync/
  files/<chemin relatif>         un fichier Drive par fichier local
  credentials/<dossier>.json     jeton de connexion de chaque compte, ex. .claude-compte2.json
  presence/<nom du PC>.json      comptes ouverts sur ce PC
```

Il n'y a pas de manifest. Le nom de chaque fichier Drive de `files/` est son chemin relatif au
dossier personnel, toujours avec `/`, et ses `appProperties` portent la date de modification
locale (`m`, en secondes) et le PC qui l'a envoyé (`pc`). Le Drive calcule lui-même le
`md5Checksum`. Une seule liste paginée de `files/` donne donc tout l'état distant, et chaque envoi
met à jour son propre fichier sans écriture commune à verrouiller entre PC.

Une suppression met le fichier Drive à la corbeille. Les autres PC la voient comme un fichier
absent du distant mais présent dans leur base, et la propagent.

Les jetons portent leur `expiresAt` dans `appProperties.exp`. Le fichier de présence d'un PC porte
une propriété par dossier de compte : l'heure de lancement, ou `0` à la fermeture.

Les noms reçus du Drive sont filtrés avant tout usage : premier segment `.claude*` ou
`.mcp.json`, ni `..`, ni `\`, ni `:`. Un fichier déposé à la main sous un autre nom est ignoré.

Chaque PC garde aussi `~/.clm-drive-state.json` : la base, c'est-à-dire pour chaque fichier le
md5, la date et l'id Drive tels qu'ils étaient à sa dernière synchro, plus l'heure de la
dernière synchro complète (`At`, 0 avant la première).

## Périmètre

Le même que `--save` :

- les dossiers des comptes listés dans `.claude-accounts.json` ;
- `.claude.json` et `.mcp.json` du compte principal ;
- `.claude-accounts.json`.

Les exclusions sont celles de `$script:SaveExcludes` (`cache`, `paste-cache`, `session-env`,
`shell-snapshots`, `ide`, `*.lock`) et les éléments partagés par lien des comptes secondaires,
synchronisés une seule fois avec `.claude`. Les binaires de clm sont exclus.

Les fichiers `.bak-sync` et `.conflit-*` ne sont pas synchronisés.

Les dossiers de `projects/` sont synchronisés tels quels. Un dossier créé sur un autre OS porte
un autre chemin encodé et reste inerte sur ce PC.

## Algorithme de synchro

Pour chaque fichier, trois états : local (md5 et date sur le disque), base (dernier état
synchronisé connu de ce PC), distant (listing de `files/`). Un fichier local dont la taille et la
date n'ont pas bougé depuis la base reprend le md5 de la base sans être relu.

| Local | Base | Distant | Action |
|---|---|---|---|
| présent | absente | absent | envoi |
| absent | absente | présent | téléchargement |
| présent | absente | présent, même md5 | adoption, base mise à jour |
| présent | absente | présent, md5 différent | conflit |
| inchangé | présente | inchangé | rien |
| changé | présente | inchangé | envoi |
| inchangé | présente | changé | téléchargement |
| changé | présente | changé, même md5 | adoption |
| changé | présente | changé, md5 différent | conflit |
| inchangé | présente | absent | suppression locale |
| absent | présente | inchangé | suppression distante |
| changé | présente | absent | envoi |
| absent | présente | changé | téléchargement |
| absent | présente | absent | oubli de la base |

En conflit, la date de modification la plus récente gagne. La version perdante est gardée sur ce
PC sous `<fichier>.conflit-<nom du PC>`, et n'est pas synchronisée.

Règle du PC qui rejoint : tant que ce PC n'a jamais fini de synchro (`At` vaut 0), un conflit sans
base est gagné par le Drive. Sans elle, un PC neuf dont Claude Code vient d'écrire ses fichiers par
défaut écraserait les fichiers partagés, plus anciens.

Garde-fous :

- plus de max(20, 10 % de la base) suppressions prévues bloquent la synchro avant toute action,
  sauf avec `--force` ;
- un fichier local illisible (tenu par Claude Code) est sauté : sa base reste, rien n'est
  supprimé de son côté ;
- un échec sur un fichier compte dans `Failed`, la synchro continue, et trois échecs consécutifs
  l'arrêtent. Tant qu'il reste un échec ou un fichier non traité, `At` n'avance pas ;
- la base est sauvée après chaque passage, même interrompu : une synchro coupée reprend où elle
  s'était arrêtée.

Les jetons de connexion suivent leur propre règle (section suivante) et ne passent jamais par la
résolution de conflit par date.

## Jetons de connexion

Source par OS : `.credentials.json` du compte sous Windows et Linux, trousseau sous Mac (lecture
existante dans `claude-credentials.ps1`, écriture ajoutée avec
`security add-generic-password -U`, découpée en morceaux comme le fait Claude Code quand le jeton
dépasse la taille d'un élément).

Sur le Drive, chaque compte a un fichier `credentials/<dossier du compte>.json` traité à part (le
dossier plutôt que le nom affiché, qui peut changer par `n`) : pour un
compte, la version gardée est celle dont `claudeAiOauth.expiresAt` est le plus grand. Un PC ne
remplace jamais un jeton local par un jeton qui expire plus tôt.

Moments où le jeton est synchronisé :

- avant de lancer un compte : téléchargement du jeton du compte s'il est plus frais ;
- avant que `Update-AccountToken` renouvelle un jeton : même téléchargement, et si le jeton reçu
  n'a pas expiré, pas de renouvellement ;
- après un renouvellement par clm : envoi immédiat ;
- à la fermeture de Claude : envoi si `expiresAt` a changé, que la synchro automatique soit
  active ou non ;
- à chaque synchro complète, pour tous les comptes, avant les fichiers.

Le `.credentials.json` des comptes est exclu de la synchro des fichiers : il ne passe que par
cette règle.

Limite connue : un même compte ouvert en même temps sur deux PC. Claude Code garde son jeton en
mémoire et le renouvelle seul, et le serveur remplace le jeton de renouvellement à chaque usage
(constat déjà documenté dans le README pour les sauvegardes) : le second PC peut être déconnecté.
Pour prévenir, chaque PC écrit dans `presence/<nom du PC>.json` l'heure de lancement de chaque
compte, remise à 0 à la fermeture, et le menu affiche `ouvert sur <PC>` sur la carte d'un compte
ouvert ailleurs depuis moins de 12 heures.

## Déclenchement

Auto (si `auto` vaut `true` et que le Drive est connecté) :

- à l'ouverture du menu, dans un runspace lancé par `Start-UsageLoader` : jetons d'abord, puis
  les fichiers, ceux de `projects/` en dernier. Le menu s'ouvre sans attendre. La synchro de fond
  continue quand un compte est lancé, et ne s'arrête que sur `q` (2 secondes d'attente) ;
- à la fermeture de Claude : la synchro de fond encore en cours est arrêtée, puis une synchro
  complète tourne avant la sortie de clm. Les deux partagent un budget de 30 secondes. Ce qui
  reste part à la prochaine synchro et un message le dit.

Manuel :

- touche `y` dans le menu, aussi cliquable dans le pied de page ;
- `clm --sync` en ligne de commande, avec la progression affichée.

## Affichage

En-tête, après la version : `sync 14:32` (dernière synchro réussie), `sync...` puis `sync 12/5508`
pendant un transfert, `sync erreur` en couleur d'alerte, `sync jamais` avant la première synchro
réussie. Rien si le Drive n'est pas connecté. Un clic sur ce texte fait comme `y`. Comme le
bouton de mise à jour, ce texte disparaît le premier quand la fenêtre est trop étroite.

## Erreurs

- Drive injoignable, délai de 15 secondes dépassé : `sync erreur`, rien n'est validé, la
  synchro suivante reprend.
- Jeton Google révoqué ou expiré sans renouvellement possible : message
  `reconnecter le Drive : clm --drive-login`.
- Fichier de plus de 5 Mo : envoi résumable de l'API Drive, en une seule requête. Un transfert
  coupé compte comme un échec et repart de zéro à la synchro suivante.
- Deux synchros sur le même PC : verrou `~/.clm-drive.lock`, sur le modèle de
  `Invoke-WithSyncLock`. Au bout de 5 secondes : `une autre synchro Drive est en cours`.
- Fichier verrouillé par Claude Code en cours d'écriture : ignoré pour cette synchro.
- Échecs de fichiers : `N fichier(s) en echec, nouvel essai a la prochaine synchro`.
- Suppressions massives : `synchro bloquee : N suppressions prevues, verifier puis lancer
  clm --sync --force`.

## Tests

Unitaires, avec l'API Drive simulée :

- comparaison local, base, distant pour chaque ligne du tableau de l'algorithme ;
- conflit : gagnant par date, nom `.conflit-<PC>` ;
- jeton : le plus grand `expiresAt` gagne, jamais de recul ;
- périmètre et exclusions, éléments partagés des comptes secondaires ;
- règle du PC qui rejoint, garde-fou des suppressions, noms Drive hostiles filtrés ;
- deux PC de bac à sable contre un Drive en mémoire : envoi, réception, conflit, suppression,
  reprise après une synchro coupée ;
- en-tête : `sync 14:32`, `sync...`, `sync erreur`, disparition en fenêtre étroite ;
- écriture du trousseau Mac avec `security` simulé, en un morceau et en plusieurs ;
- touche `y`, `--sync`, `--sync-auto`, `--drive-login`, et code de sortie de Claude gardé après
  la synchro de fermeture.

Réel, sur ce PC, contre le Drive de Florent avec un dossier de test jetable : connexion, premier
envoi, modification, téléchargement simulé d'un second PC (second dossier personnel de test),
conflit, suppression.

La CI couvre PowerShell 5.1, pwsh Windows et pwsh Linux. Mac n'est couvert que par les tests
avec `security` simulé.

## Hors v1

- Fusion de la mémoire d'un même projet entre OS (association par URL git).
- Chiffrement côté client des fichiers envoyés.
- Choix du dossier Drive autre que `clm-sync/`.
