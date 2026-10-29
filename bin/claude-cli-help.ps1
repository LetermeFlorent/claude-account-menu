$script:CliHelpText = @'
clm : comptes Claude Code, quotas, mises a jour et synchro Google Drive

Sans option, clm ouvre le menu. Chaque option ci-dessous marche sans menu,
pour une personne comme pour un script ou un agent, et sort avec le code 0
si tout va bien, 1 sinon. Un <compte> se donne par son numero dans le menu
(1 a 9), son nom ou son dossier.

Lancer
  clm                            menu des comptes
  clm -N [arguments]             lance le compte N (1 a 9) sans menu,
                                 les arguments vont a Claude Code
  clm --no-update                ne met a jour ni clm ni Claude Code
  clm --web                      menu, et sa page web dans le navigateur :
                                 comptes, Drive, affichage, archives
  clm --help, -h                 cette aide

Comptes
  clm --list                     numero, nom, dossier et e-mail des comptes
  clm --usage                    quotas 5h et 7d de chaque compte
  clm --add [nom]                nouveau compte, connexion dans le
                                 navigateur, a finir par une personne
  clm --rename <compte> <nom>    renomme, sans virgule ni nom deja pris
  clm --move <compte> <rang>     change sa place dans le menu, 1 en haut
  clm --remove <compte> --yes    retire du menu, le dossier reste en place
  clm --remove <compte> --erase --yes
                                 retire et efface le dossier du compte,
                                 apres une archive dans Telechargements
  clm --save[=nom,nom]           archive des comptes dans Telechargements
  clm --backups                  archives trouvees, la plus recente d'abord
  clm --restore=<archive> [--only=nom,nom] [--yes]
                                 restaure des comptes, l'etat actuel est
                                 archive avant ; --yes accepte les hooks,
                                 MCP, env et permissions qui changent

Mises a jour
  clm --version                  versions de clm et de Claude Code
  clm --update                   met a jour clm, puis Claude Code de
                                 chaque compte

Drive
  clm --drive-status             connexion, nom du PC, synchro auto,
                                 derniere synchro
  clm --drive-login              connecte ce PC a Google Drive, puis
                                 demande la phrase de synchro
  clm --sync-key                 saisit la phrase de synchro sur ce PC
  clm --sync-key-reset           nouvelle phrase de synchro pour tous
                                 les PC
  clm --sync-key-forget          oublie la phrase de synchro sur ce PC
  clm --sync                     synchro Drive tout de suite
  clm --sync --force             meme chose, au-dela du garde-fou des
                                 suppressions
  clm --sync-auto=on|off         synchro au lancement et a la fermeture
                                 de Claude

Reglages de synchro de ce PC, Drive connecte
  clm --prefs                    skills et MCP, coches ou non, avec leur id
  clm --prefs-on <id> [<id>...]  coche : synchronise sur ce PC
  clm --prefs-off <id> [<id>...] decoche : retire de ce PC, garde ailleurs
  clm --prefs-erase <id> [<id>...] --yes
                                 efface partout a la prochaine synchro
  Un id s'ecrit skill:<nom>, mcp:<projet>|<nom> ou global:<nom>, entre
  guillemets a cause du |, ou se reduit au nom seul s'il est unique.
  "skill:*" vise tous les skills et "mcp:*" tous les MCP, globaux compris,
  entre guillemets a cause du * ; [-] veut dire un groupe en partie coche,
  et un groupe ne s'efface pas.
  --prefs-on annule aussi un effacement demande. Apres un changement,
  clm lance la synchro. Les MCP locaux (~/.mcp.json et projets sous le
  dossier perso) suivent les cases. Les MCP globaux (mcpServers en tete
  de .claude.json) ne partent jamais vers les autres PC et sont recopies
  entre les comptes de ce PC : les decocher les retire de tous ces comptes.

Affichage de ce PC
  clm --palette auto|dark|light  couleurs du menu, auto suit le systeme
  clm --anim auto|on|off         animations du menu, auto suit le systeme
  clm --usage-poll 15..600       delai entre deux lectures de l'API de suivi, 30 par defaut

Variables
  CLM_ANIM=0|1                   coupe ou force les animations du menu,
                                 avant --anim
  STATUSLINE_BG=dark|light       fixe la palette, avant --palette

Fichiers de clm, un dossier par utilisateur
  Windows                        %LOCALAPPDATA%\clm
  Linux                          ~/.local/state/clm, ou $XDG_STATE_HOME/clm
  macOS                          ~/Library/Application Support/clm
  accounts.json                  liste des comptes, noms et dossiers
  sync-choice.json               reglages de synchro de ce PC
  sync-catalog.json              skills et MCP vus a la derniere synchro
  drive.json                     connexion Drive, secret, a ne pas partager
  display.json                   couleurs, animations et delai de lecture de ce PC
  Les anciens .claude-accounts.json et .clm-*.json du dossier perso y sont
  deplaces au premier lancement.

Fichiers du dossier perso
  .local/bin                     scripts de clm et clm.version
'@

function Get-CliKeyLines {
  $lines = New-Object 'System.Collections.Generic.List[string]'
  $lines.Add("Touches du menu")
  for ($i = 0; $i + 1 -lt $script:MenuFooter.Count; $i += 2) { $lines.Add("  " + $script:MenuFooter[$i].PadRight(8) + $script:MenuFooter[$i + 1]) }
  $lines.Add("  " + "u".PadRight(8) + "installe la nouvelle version de clm annoncee")
  return ,$lines.ToArray()
}

function Get-CliHelpLines {
  $text = @($script:CliHelpText -split "`n" | ForEach-Object { $_.TrimEnd("`r") })
  return ,[string[]]@($text + "" + (Get-CliKeyLines))
}
