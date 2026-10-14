# Synchro Drive de clm : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** synchroniser comptes, config, conversations et jetons de connexion de clm entre PC
Windows, Mac et Linux par l'API Google Drive, en automatique et à la demande.

**Architecture:** une couche Drive (config locale, OAuth avec PKCE sur `127.0.0.1`, appels REST),
une couche fichiers (périmètre, empreintes MD5, état de base local), un plan de synchro pur à trois
états (local, base, distant), un orchestrateur qui exécute le plan, puis l'intégration au menu
(tâche de fond, en-tête, touche `y`, présence) et au lancement d'un compte.

**Tech Stack:** PowerShell 5.1 et pwsh 7, `Invoke-WebRequest`, `System.Net.Sockets.TcpListener`,
API Google Drive v3, OAuth 2.0 Google pour application de bureau.

**Spec:** `docs/superpowers/specs/2026-10-14-sync-drive-design.md`

## Écart assumé avec la spec

La spec prévoyait un `manifest.json` partagé. Le plan s'en passe : chaque fichier Drive porte son
chemin relatif dans `name`, son MD5 dans `md5Checksum` (calculé par Drive), et sa date et son PC
dans `appProperties` (`m`, `pc`). Le listing du dossier tient lieu de manifest, il n'y a plus
d'écriture concurrente d'un fichier commun. Une suppression se lit par l'absence d'un fichier
présent dans la base locale, sans entrée `deleted`. La spec est mise à jour dans la tâche 9.

## Global Constraints

- Aucun commentaire dans le code, identifiants en anglais, chaînes affichées sans accents.
- Compatible PowerShell 5.1 et pwsh 7 sur Windows, Linux, Mac.
- Pas de dépendance externe : seulement les API .NET et les cmdlets livrées.
- Délai de 15 s par requête de métadonnées, 120 s par transfert de contenu.
- Portée OAuth : `https://www.googleapis.com/auth/drive.file`.
- `~/.clm-drive.json` et `~/.clm-drive-state.json` ne sont jamais synchronisés.
- Tests dans `tests/sync/*.checks.ps1`, lancés par `tests/run.ps1`, API Drive simulée.

## Review Focus

- Énumération locale vide ou partielle (compte absent, dossier illisible) avec une base pleine :
  la synchro ne doit pas vider le Drive. Garde-fou de suppressions massives, testé tâche 5.
- Fichier ouvert en écriture par Claude Code pendant la lecture ou le remplacement : ignoré pour
  ce passage, la synchro continue. Testé tâche 5.
- Premier passage sur un PC neuf (base vide) face à un Drive plein : tout se télécharge, rien ne
  se supprime. Testé tâche 4.
- Jeton de connexion local absent (compte jamais connecté sur ce PC) : le jeton distant est
  écrit. Testé tâche 6.
- Chemins avec espaces, accents et `/` : un nom Drive par chemin relatif, aller-retour exact.
  Testé tâche 3.

## Fichiers

| Fichier | Rôle |
|---|---|
| `bin/claude-drive-config.ps1` | lecture et écriture de `~/.clm-drive.json`, nom du PC, réglage auto |
| `bin/claude-drive-auth.ps1` | PKCE, URL de consentement, réception du code, échange et renouvellement du jeton Google |
| `bin/claude-drive-api.ps1` | requêtes Drive : dossiers, listing, envoi, téléchargement, corbeille, métadonnées |
| `bin/claude-drive-files.ps1` | périmètre local, exclusions, MD5, état de base |
| `bin/claude-drive-plan.ps1` | plan de synchro pur, chemin de conflit, choix du jeton le plus frais |
| `bin/claude-drive-creds.ps1` | synchro des jetons de connexion et présence |
| `bin/claude-drive-sync.ps1` | orchestrateur `Invoke-DriveSync`, hooks de lancement et de fermeture |
| `bin/claude-drive-job.ps1` | tâche de fond du menu et texte d'en-tête |
| `bin/claude-credentials.ps1` | ajout de `Write-AccountCredential`, `Write-CredentialFile` y est déplacé |

### Task 1: config et nom du PC

**Files:** Create `bin/claude-drive-config.ps1`, Test `tests/sync/config.checks.ps1`

**Interfaces:**
- Produces: `$script:DriveConfigPath`, `Read-DriveConfig` (hashtable ou `$null`),
  `Save-DriveConfig $Config`, `Test-DriveConnected` (bool : config avec `refreshToken`),
  `Test-DriveAuto` (connecté et `auto` différent de `$false`), `Set-DriveAuto [bool]`,
  `Get-DrivePcName` (`pc` de la config, sinon `[Environment]::MachineName`).

- [ ] Test : sans fichier, `Test-DriveConnected` vaut `$false` ; après
  `Save-DriveConfig @{ refreshToken = "r"; clientId = "c" }`, il vaut `$true`, `Test-DriveAuto`
  vaut `$true`, puis `$false` après `Set-DriveAuto $false` ; `Get-DrivePcName` rend le nom de la
  machine, puis `"PC-TEST"` quand la config porte `pc = "PC-TEST"`.
- [ ] Implémentation avec `Read-JsonFile` et `ConvertTo-JsonText` de `claude-json.ps1`, écriture
  sans BOM, `chmod 600` hors Windows.
- [ ] Suites, lint, commit.

### Task 2: OAuth Google

**Files:** Create `bin/claude-drive-auth.ps1`, Test `tests/sync/auth.checks.ps1`

**Interfaces:**
- Produces: `New-PkcePair` (`@{ Verifier; Challenge }`, challenge = base64url SHA-256),
  `Get-DriveAuthUrl $ClientId $Redirect $Challenge $State`,
  `ConvertFrom-AuthRequest [string]$RequestLine` (`@{ Code; State; Error }` depuis
  `GET /?code=...&state=... HTTP/1.1`), `Receive-AuthCode $Listener $Timeout`,
  `Request-DriveToken $Config $Form` (POST `https://oauth2.googleapis.com/token`,
  `application/x-www-form-urlencoded`), `Get-DriveToken` (jeton d'accès valable au moins 60 s,
  renouvelé sinon ; `invalid_grant` lève `reconnecter le Drive : clm --drive-login`),
  `Invoke-DriveLogin` (interactif).

- [ ] Tests : verifier PKCE de 43 caractères en base64url sans `=`, challenge égal au SHA-256 du
  verifier recalculé dans le test ; URL contenant `access_type=offline`, `prompt=consent`,
  `code_challenge_method=S256` et la portée encodée ; lecture du code et de l'état d'une ligne de
  requête, erreur `access_denied` ; `Get-DriveToken` avec la requête de jeton simulée : jeton
  encore valable rendu sans appel, jeton expiré renouvelé et sauvé, `invalid_grant` qui lève le
  message de reconnexion.
- [ ] Implémentation : écoute `TcpListener` sur `127.0.0.1` port 0, redirection
  `http://127.0.0.1:<port>`, ouverture du navigateur (`Start-Process` sous Windows, `open` sous
  Mac, `xdg-open` sous Linux), URL aussi affichée, réponse HTML courte `clm : Drive connecte, tu
  peux fermer cet onglet`.
- [ ] Suites, lint, commit.

### Task 3: API Drive

**Files:** Create `bin/claude-drive-api.ps1`, Test `tests/sync/api.checks.ps1`

**Interfaces:**
- Produces: `Invoke-DriveRequest $Method $Uri $Body $ContentType $Timeout $OutFile $Headers`
  (ajoute `Authorization`, réessaie une fois après un 401 en forçant le renouvellement),
  `New-MultipartBody [string]$MetaJson [byte[]]$Bytes [string]$Boundary` (byte[]),
  `Get-DriveFolders` (`@{ Root; Files; Credentials; Presence }`, créés si absents, ids gardés
  dans la config), `Get-DriveListing $FolderId` (hashtable nom vers
  `@{ Id; Md5; M; Pc; Exp; Props }`, doublons : le plus grand `m` gardé, les autres mis à la
  corbeille), `Send-DriveFile $FolderId $Name $Path $Props $Id` (POST si `$Id` vide, PATCH sinon,
  multipart sous 5 Mo, resumable au-delà, rend `@{ Id; Md5 }`),
  `Send-DriveText $FolderId $Name $Text $Props $Id`, `Receive-DriveFile $Id $Path` (téléchargement
  vers un temporaire puis remplacement), `Get-DriveText $Id`, `Remove-DriveFile $Id` (corbeille),
  `Set-DriveProps $Id $Props`.

- [ ] Tests : `New-MultipartBody` produit les deux parties, `Content-Type: application/json` puis
  `application/octet-stream`, octets binaires intacts ; `Get-DriveListing` avec
  `Invoke-DriveRequest` simulé sur deux pages (`nextPageToken`) ; doublon résolu ; nom avec
  espaces, accents et `/` rendu tel quel ; `Send-DriveFile` choisit POST, PATCH, multipart ou
  resumable selon `$Id` et la taille.
- [ ] Implémentation : URLs `https://www.googleapis.com/drive/v3/files` et
  `https://www.googleapis.com/upload/drive/v3/files`, `fields=nextPageToken,files(id,name,md5Checksum,appProperties)`,
  `pageSize=1000`, requête `'<id>' in parents and trashed=false`, apostrophes et barres obliques
  inverses échappées dans les requêtes, envoi resumable par morceaux de 8 Mo avec deux réessais
  par morceau.
- [ ] Suites, lint, commit.

### Task 4: fichiers locaux et plan

**Files:** Create `bin/claude-drive-files.ps1`, `bin/claude-drive-plan.ps1`, Test
`tests/sync/plan.checks.ps1`, `tests/sync/files.checks.ps1`

**Interfaces:**
- Produces: `Test-SyncExcluded [string]$Rel [string[]]$Patterns`, `Get-SyncPatterns $Accs`
  (`Get-SaveExcludes` plus `*.bak-sync`, `*.conflit-*`, `.credentials.json`, `*.tmp`),
  `Get-SyncRoots $Accs` (`Get-AccountItems` plus `.claude-accounts.json`),
  `Get-LocalFiles $Roots $Patterns $Base` (hashtable chemin relatif vers
  `@{ Md5; M; Size; Full }`, liens et jonctions ignorés, MD5 repris de la base quand taille et
  date sont identiques), `Get-FileMd5 $Path` (partage lecture-écriture), `Read-DriveState`,
  `Save-DriveState $State`, `Get-SyncPlan $Local $Base $Remote` (liste ordonnée de
  `@{ Kind; Path }`, `Kind` parmi `upload`, `download`, `delete-local`, `delete-remote`,
  `keep-local`, `keep-remote`, `adopt`, `forget` ; chemins hors `projects/` d'abord),
  `Get-ConflictPath $Path $Pc`.

- [ ] Tests du plan, une ligne par cas : rien ; local seul nouveau ; distant seul nouveau ; local
  modifié ; distant modifié ; les deux modifiés au même MD5 (`adopt`) ; conflit gagné par le
  local (`keep-local`) ; conflit gagné par le distant (`keep-remote`) ; supprimé localement non
  modifié ailleurs (`delete-remote`) ; supprimé localement mais modifié ailleurs (`download`) ;
  supprimé à distance (`delete-local`) ; supprimé à distance mais modifié localement
  (`upload`) ; supprimé des deux côtés (`forget`) ; base vide et Drive plein : que des
  `download` ; ordre : `.claude/settings.json` avant `.claude/projects/x.jsonl`.
- [ ] Tests fichiers : exclusions (`cache` en composant, `*.lock`, `.claude-compte2/skills`,
  `.credentials.json`, `x.conflit-PC`), jonction ignorée, MD5 repris de la base sans relecture,
  `Get-ConflictPath ".claude/settings.json" "MAC"` vaut `.claude/settings.json.conflit-MAC`.
- [ ] Implémentation, suites, lint, commit.

### Task 5: orchestrateur

**Files:** Create `bin/claude-drive-sync.ps1`, Test `tests/sync/sync.checks.ps1`

**Interfaces:**
- Consumes: tâches 1 à 4, `Sync-DriveCredentials` de la tâche 6 (appel protégé par
  `Get-Command`).
- Produces: `Invoke-DriveSync $Ctl $DeadlineMs [switch]$Force` rend
  `@{ Ok; Error; At; Left; Up; Down; Deleted; Conflicts; Away }` ; `$Ctl.Stop` arrête entre deux
  fichiers ; `$Ctl.Progress` vaut `"n/total"`. `$script:DriveDeleteLimit = 20` : au-delà de
  `max(20, 10 % de la base)` suppressions, erreur `synchro bloquee : <n> suppressions prevues,
  verifier puis lancer clm --sync --force` sans rien supprimer.

- [ ] Tests avec un faux Drive en mémoire (fonctions `Get-DriveFolders`, `Get-DriveListing`,
  `Send-DriveFile`, `Receive-DriveFile`, `Remove-DriveFile` redéfinies) et deux dossiers
  personnels de bac à sable qui jouent deux PC : envoi initial, réception sur le second PC,
  modification propagée, suppression propagée, conflit avec copie `.conflit-<PC>`, garde-fou de
  suppressions, `--force` qui passe outre, arrêt par `$Ctl.Stop` avec base partielle sauvée,
  fichier verrouillé ignoré, échéance dépassée qui rend `Left` supérieur à 0.
- [ ] Implémentation, suites, lint, commit.

### Task 6: jetons de connexion et présence

**Files:** Create `bin/claude-drive-creds.ps1`, Modify `bin/claude-credentials.ps1`,
`bin/claude-token-refresh.ps1`, Test `tests/sync/creds.checks.ps1`

**Interfaces:**
- Produces: `Get-CredentialExpiry $Cred` (long, 0 si absent), `Select-FresherCredential $LocalExp
  $RemoteExp` (`local`, `remote`, `same`), `Write-AccountCredential $Acc $Cred` (trousseau sous
  Mac, fichier sinon), `Write-KeychainCredential $ConfigDir $Json`,
  `Sync-AccountCredential $Acc $Folders $Listing` (rend `local`, `remote` ou `same`),
  `Sync-DriveCredentials $Folders` (tous les comptes, une seule lecture du listing),
  `Send-AccountCredential $Acc $Cred`, `Set-DrivePresence $Acc [bool]$Open`,
  `Get-AwayMap $Listing $Pc $NowSec` (Dir vers nom du PC, moins de 12 h, autre PC).
- [ ] Tests : jeton distant plus frais écrit, plus ancien ignoré, local absent remplacé, local plus
  frais envoyé avec `appProperties.exp` ; écriture trousseau avec `security` simulé ;
  `Get-AwayMap` filtre son propre PC et les présences de plus de 12 h ; hooks de
  `Update-AccountToken` sans effet quand le Drive n'est pas connecté.
- [ ] Implémentation : `Update-AccountToken` relit d'abord le jeton distant quand le Drive est
  connecté et le prend s'il n'a pas expiré, puis envoie le jeton renouvelé, toutes erreurs Drive
  avalées en silence pour ne jamais casser la lecture des quotas.
- [ ] Suites, lint, commit.

### Task 7: menu

**Files:** Create `bin/claude-drive-job.ps1`, Modify `bin/claude-menu-view.ps1`,
`bin/claude-menu-loop.ps1`, `bin/claude-menu-keys.ps1`, `bin/claude-ui-chrome.ps1`,
`bin/claude-menu-screen.ps1`, `bin/claude-menu-card.ps1`, Test `tests/sync/job.checks.ps1`,
`tests/menu/layout.checks.ps1`

**Interfaces:**
- Produces: `$script:DriveJob` (`@{ Loader; Ctl; Last; Away }`), `Start-DriveJob`,
  `Step-DriveJob $Job` (vrai si l'état a changé), `Stop-DriveJob`, `Get-DriveTag` (`""`,
  `sync...`, `sync 12/5508`, `sync 14:32`, `sync erreur`), `Get-DriveSyncMsg $Result`,
  action `drivesync` sur la touche `y`.
- [ ] Tests : tag pour chaque état ; en-tête avec version, tag et bouton, le tag disparaît le
  premier quand la largeur baisse ; clic sur le tag rend `y` ; touche `y` sans Drive, pendant
  une synchro, puis au repos ; `Away` affiché `ouvert sur MAC` sur la carte ; pied de page avec
  `y sync` et nouveau seuil d'une ligne.
- [ ] Implémentation, suites, lint, commit.

### Task 8: ligne de commande et lancement

**Files:** Modify `bin/claude-menu.ps1`, `tests/run.ps1`

- [ ] `--drive-login`, `--sync` (avec `--force`), `--sync-auto=on|off`.
- [ ] `Start-Account` : avant le lancement, `Sync-DriveBeforeLaunch $Acc` (jeton du compte et
  présence) ; après, `Sync-DriveAfterExit $Acc` (présence retirée, synchro de 30 s au plus),
  `LASTEXITCODE` de Claude conservé.
- [ ] Tests de la lecture des options par une fonction `Get-DriveCliAction $Args`.
- [ ] Suites, lint, commit.

### Task 9: documentation et essai réel

- [ ] README : section « Synchronisation entre PC » avec les étapes Google Cloud (projet, API
  Drive, écran de consentement en production, identifiant de bureau), les commandes, la touche
  `y`, l'en-tête, la limite du même compte ouvert sur deux PC, le garde-fou.
- [ ] Spec : remplacer la section manifest par le stockage en métadonnées.
- [ ] Essai réel une fois l'identifiant OAuth créé par Florent.
- [ ] Push, CI.
