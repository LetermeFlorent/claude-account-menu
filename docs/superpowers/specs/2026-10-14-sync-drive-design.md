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
  manifest.json
  files/<id Drive>          un fichier Drive par fichier local
  credentials/<label>.json  jeton de connexion de chaque compte
  presence/<nom du PC>.json comptes ouverts sur ce PC, avec l'heure
```

`manifest.json` liste chaque fichier synchronisé :

```json
{
  "version": 12,
  "files": {
    ".claude/settings.json": { "id": "1AbC...", "sha": "e3b0...", "mtime": 1760450000, "size": 812, "pc": "PC-BUREAU" },
    ".claude/old.md": { "deleted": true, "mtime": 1760450100, "pc": "MAC" }
  }
}
```

Les chemins sont relatifs au dossier personnel, toujours avec `/`. Une suppression laisse une
entrée `deleted` pour que les autres PC la propagent.

Chaque PC garde aussi `~/.clm-sync-state.json` : le manifest tel qu'il était à sa dernière
synchro réussie. C'est la base de comparaison pour savoir qui a changé quoi.

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

Pour chaque fichier, trois états : local (hash et date sur le disque), base (dernier état
synchronisé connu de ce PC), distant (manifest du Drive).

| Local vs base | Distant vs base | Action |
|---|---|---|
| inchangé | inchangé | rien |
| changé | inchangé | envoi |
| inchangé | changé | téléchargement (ou suppression locale si `deleted`) |
| changé | changé, même hash | rien, base mise à jour |
| changé | changé, hash différent | conflit |

En conflit, la date de modification la plus récente gagne. La version perdante est gardée à côté
sous `<fichier>.conflit-<nom du PC>`, localement, et n'est pas synchronisée.

Les jetons de connexion suivent leur propre règle (section suivante) et ne passent jamais par la
résolution de conflit par date.

Fin de synchro : le manifest fusionné est écrit sur le Drive en vérifiant que sa version n'a pas
bougé (lecture de `version` juste avant l'écriture). Si elle a bougé, clm relit le manifest,
refait la comparaison pour les fichiers concernés et réessaie, trois fois au plus. Le state local
n'est écrit qu'après l'écriture du manifest.

## Jetons de connexion

Source par OS : `.credentials.json` du compte sous Windows et Linux, trousseau sous Mac (lecture
existante dans `claude-credentials.ps1`, écriture ajoutée avec
`security add-generic-password -U`, découpée en morceaux comme le fait Claude Code quand le jeton
dépasse la taille d'un élément).

Sur le Drive, chaque compte a un fichier `credentials/<label>.json` traité à part : pour un
compte, la version gardée est celle dont `claudeAiOauth.expiresAt` est le plus grand. Un PC ne
remplace jamais un jeton local par un jeton qui expire plus tôt.

Moments où le jeton est synchronisé :

- avant de lancer un compte : téléchargement du jeton du compte s'il est plus frais ;
- avant que `Update-AccountToken` renouvelle un jeton : même téléchargement, et si le jeton reçu
  n'a pas expiré, pas de renouvellement ;
- après un renouvellement par clm : envoi immédiat ;
- à la fermeture de Claude : envoi si `expiresAt` a changé.

Limite connue : un même compte ouvert en même temps sur deux PC. Claude Code garde son jeton en
mémoire et le renouvelle seul. Si le jeton de renouvellement est à usage unique, le second PC peut
être déconnecté. À vérifier pendant le développement en renouvelant deux fois le même jeton de
renouvellement sur un compte de test. Pour prévenir, chaque PC écrit dans
`presence/<nom du PC>.json` les comptes qu'il a lancés et l'heure, et le menu affiche
`ouvert sur <PC>` à côté d'un compte ouvert ailleurs depuis moins de 12 heures.

## Déclenchement

Auto (si `auto` vaut `true` et que le Drive est connecté) :

- au lancement de clm, dans un runspace comme `Start-UsageLoader` : jetons et config d'abord,
  puis le reste. Le menu s'ouvre sans attendre ;
- à la fermeture de Claude : envoi de ce qui a changé, avant la sortie de clm. Au-delà de
  30 secondes, le reste part à la prochaine synchro et un message le dit.

Manuel :

- touche `y` dans le menu, aussi cliquable dans le pied de page ;
- `clm --sync` en ligne de commande, avec la progression affichée.

## Affichage

En-tête, après la version : `sync 14:32` (dernière synchro réussie), `sync...` pendant un
transfert, `sync erreur` en couleur d'alerte. Rien si le Drive n'est pas connecté. Comme le
bouton de mise à jour, ce texte disparaît le premier quand la fenêtre est trop étroite.

## Erreurs

- Drive injoignable, délai de 15 secondes dépassé : `sync erreur`, rien n'est validé, la
  synchro suivante reprend.
- Jeton Google révoqué ou expiré sans renouvellement possible : message
  `reconnecter le Drive : clm --drive-login`.
- Fichier de plus de 5 Mo : envoi résumable de l'API Drive. Un transfert coupé reprend à l'octet
  près dans la même synchro, sinon il repart de zéro à la suivante.
- Deux synchros sur le même PC : verrou `~/.clm-drive.lock`, sur le modèle de
  `Invoke-WithSyncLock`.
- Fichier verrouillé par Claude Code en cours d'écriture : ignoré pour cette synchro.

## Tests

Unitaires, avec l'API Drive simulée :

- comparaison local, base, distant pour chaque ligne du tableau de l'algorithme ;
- conflit : gagnant par date, nom `.conflit-<PC>` ;
- jeton : le plus grand `expiresAt` gagne, jamais de recul ;
- périmètre et exclusions, éléments partagés des comptes secondaires ;
- réessai quand la version du manifest a bougé ;
- en-tête : `sync 14:32`, `sync...`, `sync erreur`, disparition en fenêtre étroite ;
- écriture du trousseau Mac avec `security` simulé ;
- touche `y` et `--sync`.

Réel, sur ce PC, contre le Drive de Florent avec un dossier de test jetable : connexion, premier
envoi, modification, téléchargement simulé d'un second PC (second dossier personnel de test),
conflit, suppression.

La CI couvre PowerShell 5.1, pwsh Windows et pwsh Linux. Mac n'est couvert que par les tests
avec `security` simulé.

## Hors v1

- Fusion de la mémoire d'un même projet entre OS (association par URL git).
- Chiffrement côté client des fichiers envoyés.
- Choix du dossier Drive autre que `clm-sync/`.
