. (Join-Path $PSScriptRoot "actions-fakes.ps1")

try {
  Save-Registry @([PSCustomObject]@{ Label = "perso"; Dir = ".claude" }, [PSCustomObject]@{ Label = "Pro"; Dir = ".claude-compte2" }, [PSCustomObject]@{ Label = "jeu"; Dir = ".claude-compte3" })
  $script:Startup = $null
  $script:DriveJob = $null
  $script:ClmCheck = $null
  Reset-MenuState @("", $script:Ink.Dim) 0

  $r = Invoke-ActTest @{ do = "voler" }
  Assert-Equal ("200 False " + (Get-ClmText "server.unknownAction" @("voler")) + " none") ("" + $r.Code + " " + $r.Ok + " " + $r.Msg + " " + $r.Next) "web action : action inconnue"
  $script:Startup = @{ Steps = @(@{ Name = "claude"; State = "run" }) }
  $r = Invoke-ActTest @{ do = "rename"; acc = ".claude-compte2"; name = "Travail" }
  Assert-Equal "409 Pro" ("" + $r.Code + " " + @(Get-Accounts)[1].Label) "web action : refusee pendant le demarrage"
  $r = Invoke-ActTest @{ do = "backups-of"; name = "claude-comptes-20261003-100000.zip" }
  Assert-Equal "200 True" ("" + $r.Code + " " + $r.Ok) "web action : lecture d'une sauvegarde pendant le demarrage"
  $script:Startup = $null

  $script:ActStops = 0
  $r = Invoke-ActTest @{ do = "rename"; acc = ".claude-compte2"; name = " Travail " }
  Assert-Equal "True Pro renomme en Travail" ("" + $r.Ok + " " + $r.Msg) "web action : renommer"
  Assert-Equal "perso=.claude|Travail=.claude-compte2|jeu=.claude-compte3" (Get-ActOrder) "web action : nom enregistre"
  Assert-True ($script:ActStops -eq 1) "web action : lecture des quotas arretee avant le changement"
  Assert-Equal "  Pro renomme en Travail" $script:MenuState.Msg[0] "web action : message aussi dans le terminal"
  Assert-Equal 3 $script:MenuState.Entries.Count "web action : menu du terminal rafraichi"
  $r = Invoke-ActTest @{ do = "rename"; acc = ".claude-compte3"; name = "perso" }
  Assert-Equal "False le nom perso est deja pris" ("" + $r.Ok + " " + $r.Msg) "web action : nom deja pris"
  Assert-Equal "alert" (Get-WebTone $script:MenuState.Msg[1]) "web action : erreur en rouge dans le terminal"
  $r = Invoke-ActTest @{ do = "rename"; acc = ".claude-compte9"; name = "x" }
  Assert-Equal (Get-ClmText "server.unknownAccount" @(".claude-compte9")) $r.Msg "web action : compte inconnu"
  $r = Invoke-ActTest @{ do = "rename"; acc = ".CLAUDE-COMPTE2"; name = "x" }
  Assert-Equal (Get-ClmText "server.unknownAccount" @(".CLAUDE-COMPTE2")) $r.Msg "web action : dossier compare a la lettre pres"

  $r = Invoke-ActTest @{ do = "move"; acc = ".claude-compte3"; rank = 1 }
  Assert-Equal "True jeu passe au rang 1" ("" + $r.Ok + " " + $r.Msg) "web action : changer l'ordre"
  Assert-Equal "jeu=.claude-compte3|perso=.claude|Travail=.claude-compte2" (Get-ActOrder) "web action : ordre enregistre"
  foreach ($bad in @("haut", "-1", "1.5", "")) {
    $r = Invoke-ActTest @{ do = "move"; acc = ".claude-compte3"; rank = $bad }
    Assert-Equal (Get-ClmText "server.badRank") $r.Msg ("web action : rang refuse [" + $bad + "]")
  }
  Assert-Equal "rang 9 hors de la liste, de 1 a 3" (Invoke-ActTest @{ do = "move"; acc = ".claude"; rank = 9 }).Msg "web action : rang trop grand"

  $r = Invoke-ActTest @{ do = "add"; name = " Neuf " }
  Assert-Equal "True add Neuf" ("" + $r.Ok + " " + $r.Next + " " + $r.Arg) "web action : ajout passe la main au terminal"
  $r = Invoke-ActTest @{ do = "add" }
  Assert-True ($r.Ok -and $r.Next -eq "add" -and $r.Arg -eq "") "web action : ajout avec le nom par defaut"
  $r = Invoke-ActTest @{ do = "add"; name = "a,b" }
  Assert-Equal "False none" ("" + $r.Ok + " " + $r.Next) "web action : nom d'ajout refuse avant de quitter le menu"

  $script:MenuState.Entries[1].Pending = $false
  $r = Invoke-ActTest @{ do = "refresh"; acc = ".claude" }
  Assert-Equal "perso : relecture demandee" $r.Msg "web action : relire les quotas d'un compte"
  Assert-True ($script:MenuState.Entries[1].Force -and $script:MenuState.Sel -eq 0) "web action : relecture sans bouger la selection"

  $r = Invoke-ActTest @{ do = "remove"; acc = ".claude-compte2" }
  Assert-Equal "True Travail retire du menu" ("" + $r.Ok + " " + $r.Msg) "web action : retirer un compte"
  Assert-Equal "jeu=.claude-compte3|perso=.claude" (Get-ActOrder) "web action : compte retire du registre"
  $r = Invoke-ActTest @{ do = "remove"; acc = ".claude"; erase = $true }
  Assert-Equal "le dossier .claude n'est jamais efface" $r.Msg "web action : dossier principal jamais efface"

  $r = Invoke-ActTest @{ do = "drivesync" }
  Assert-Equal ("False " + (Get-ClmText "server.driveOff")) ("" + $r.Ok + " " + $r.Msg) "web action : synchro sans Drive"
  $r = Invoke-ActTest @{ do = "drivelogin" }
  Assert-Equal "True drivelogin" ("" + $r.Ok + " " + $r.Next) "web action : connexion Drive passe la main au terminal"
  $script:DriveJob = New-DriveJob $true 0
  Assert-Equal (Get-ClmText "server.driveOn") (Invoke-ActTest @{ do = "drivelogin" }).Msg "web action : Drive deja connecte"
  $script:ActSyncs = 0
  Assert-Equal "synchro Drive lancee" (Invoke-ActTest @{ do = "drivesync" }).Msg "web action : synchro lancee"
  $r = Invoke-ActTest @{ do = "driveauto"; on = $false }
  Assert-Equal ((Get-ClmText "server.autoOff") + " False") ($r.Msg + " " + $script:ActAuto) "web action : synchro automatique coupee"
  $r = Invoke-ActTest @{ do = "driveauto"; on = $true }
  Assert-Equal ((Get-ClmText "server.autoOn") + " True") ($r.Msg + " " + $script:ActAuto) "web action : synchro automatique activee"

  $r = Invoke-ActTest @{ do = "pref"; id = "skill:dessin"; move = "erase" }
  Assert-Equal ("True " + (Get-ClmText "server.prefErase" @("dessin"))) ("" + $r.Ok + " " + $r.Msg) "web action : effacer un skill partout"
  Assert-True ((Read-SyncChoice).Erase.skills.Contains("dessin")) "web action : effacement enregistre"
  Assert-True ($script:ActSyncs -eq 2 -and @($r.Data.lines).Count -eq 3) "web action : synchro lancee, reglages renvoyes"
  $r = Invoke-ActTest @{ do = "pref"; id = "skill:dessin"; move = "on" }
  Assert-True ($r.Ok -and -not (Read-SyncChoice).Erase.skills.Contains("dessin")) "web action : effacement annule"
  $r = Invoke-ActTest @{ do = "pref"; id = "skill:*"; move = "erase" }
  Assert-Equal (Get-ClmText "server.groupErase") $r.Msg "web action : groupe jamais efface d'un coup"
  Assert-Equal (Get-ClmText "server.unknownMove" @("vider")) (Invoke-ActTest @{ do = "pref"; id = "skill:dessin"; move = "vider" }).Msg "web action : choix inconnu"
  Assert-True ((Invoke-ActTest @{ do = "pref"; id = "skill:rien"; move = "on" }).Msg -like "reglage inconnu : skill:rien*") "web action : reglage inconnu"
  $script:ActSyncs = 0
  $r = Invoke-ActTest @{ do = "pref"; id = "skill:dessin"; move = "off"; pc = "loin" }
  Assert-Equal ("True " + (Get-ClmText "server.pcPrefOff" @("dessin", "loin"))) ("" + $r.Ok + " " + $r.Msg) "web action : skill decoche pour un autre PC"
  Assert-True ((-not (Read-SyncChoice).Asks["loin"].skills["dessin"].On) -and $script:ActSyncs -eq 1) "web action : demande enregistree, synchro lancee"
  $loin = @(@($r.Data.pcs) | Where-Object { $_.name -eq "loin" })[0]
  Assert-Equal "False True" ("" + @($loin.lines)[2].on + " " + @($loin.lines)[2].wait) "web action : case de l'autre PC en attente"
  Assert-Equal "ICI loin vieux" ($r.Data.me + " " + (@($r.Data.pcs | ForEach-Object { $_.name }) -join " ")) "web action : liste des PC"
  $r = Invoke-ActTest @{ do = "pref"; id = "skill:dessin"; move = "on"; pc = "loin" }
  Assert-True ($r.Ok -and -not (Read-SyncChoice).Asks.ContainsKey("loin")) "web action : case remise, demande retiree"
  Assert-Equal (Get-ClmText "server.eraseHereOnly") (Invoke-ActTest @{ do = "pref"; id = "skill:dessin"; move = "erase"; pc = "loin" }).Msg "web action : pas d'effacement pour un autre PC"
  Assert-Equal ("vieux : " + $script:PrefsPcOld) (Invoke-ActTest @{ do = "pref"; id = "skill:dessin"; move = "on"; pc = "vieux" }).Msg "web action : PC sans clm a jour refuse"
  Assert-Equal (Get-ClmText "server.unknownPc" @("nulle part")) (Invoke-ActTest @{ do = "pref"; id = "skill:dessin"; move = "on"; pc = "nulle part" }).Msg "web action : PC inconnu"
  $r = Invoke-ActTest @{ do = "pref"; id = "skill:dessin"; move = "off"; pc = "ICI" }
  Assert-True ($r.Ok -and (Read-SyncChoice).skills["dessin"] -eq $false) "web action : ce PC par son nom, reglage local"

  $r = Invoke-ActTest @{ do = "display"; palette = "light" }
  $d = Read-DisplayConfig
  Assert-Equal "True light auto" ("" + $r.Ok + " " + $d.palette + " " + $d.anim) "web action : couleurs claires"
  $r = Invoke-ActTest @{ do = "display"; anim = "off" }
  $d = Read-DisplayConfig
  Assert-Equal "light off False" ($d.palette + " " + $d.anim + " " + $script:MotionOn) "web action : animations coupees tout de suite"
  Assert-True ((Invoke-ActTest @{ do = "display"; palette = "rose" }).Msg -like "couleurs inconnues*") "web action : couleur inconnue"

  $r = Invoke-ActTest @{ do = "save"; accs = @(".claude-compte3") }
  Assert-Equal ("True " + (Get-ClmText "server.saved" @("C:\dl\claude-comptes.zip")) + " jeu Sauvegarde") ("" + $r.Ok + " " + $r.Msg + " " + $script:ActBackup + " " + $script:ActWork) "web action : sauvegarde des comptes choisis"
  Assert-Equal 1 @($r.Data.items).Count "web action : liste des sauvegardes renvoyee"
  Assert-Equal (Get-ClmText "server.noAccount") (Invoke-ActTest @{ do = "save"; accs = @() }).Msg "web action : sauvegarde sans compte"
  Assert-Equal (Get-ClmText "server.unknownAccount" @(".claude-x")) (Invoke-ActTest @{ do = "save"; accs = @(".claude", ".claude-x") }).Msg "web action : sauvegarde d'un compte inconnu"

  $r = Invoke-ActTest @{ do = "backups-of"; name = "claude-comptes-20261003-100000.zip" }
  Assert-Equal "perso Pro" (@($r.Data | ForEach-Object { $_.label }) -join " ") "web action : comptes d'une sauvegarde"
  $r = Invoke-ActTest @{ do = "restore"; name = "claude-comptes-20261003-100000.zip"; accs = @(".claude-compte2") }
  Assert-Equal "True restauration terminee claude-comptes-20261003-100000.zip:.claude-compte2" ("" + $r.Ok + " " + $r.Msg + " " + $script:ActRestored) "web action : restauration"
  Assert-True ((Invoke-ActTest @{ do = "restore"; name = "..\x.zip"; accs = @(".claude") }).Msg.StartsWith((Get-ClmText "server.hiddenError" @("W3")).Split(",")[0])) "web action : sauvegarde hors du dossier refusee, sans chemin dans la page"
  Assert-True ($script:MenuState.Msg[0].Contains("W3") -and $script:MenuState.Msg[0].Contains((Get-ClmText "server.backupNotFound" @("..\x.zip")))) "web action : detail du refus dans le terminal"
  Assert-Equal (Get-ClmText "server.unknownAccount" @(".claude-compte3")) (Invoke-ActTest @{ do = "restore"; name = "claude-comptes-20261003-100000.zip"; accs = @(".claude-compte3") }).Msg "web action : compte absent de la sauvegarde"

  Assert-Equal (Get-ClmText "server.noUpdate") (Invoke-ActTest @{ do = "selfupdate" }).Msg "web action : pas de mise a jour"
  $script:ClmCheck = @{ Latest = @{ Number = 12; Sha = "abcdef123456" } }
  Assert-Equal "selfupdate" (Invoke-ActTest @{ do = "selfupdate" }).Next "web action : mise a jour passe la main au menu"
} finally { Restore-ActFakes }
