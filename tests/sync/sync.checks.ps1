. (Join-Path $PSScriptRoot "fake-drive.ps1")
Use-Pc "PCA"
Save-Registry @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" })
Set-PcFile ".claude/settings.json" "a1" 1700000000
Set-PcFile ".claude/projects/p/memory/s.md" "s1"
Set-PcFile ".claude/cache/x.bin" "cache"
$r = Invoke-DriveSync
Assert-True $r.Ok ("premier envoi reussi " + $r.Error)
Assert-Equal 3 $r.Up "premier envoi : registre, reglages, memoire"
$fakeKeys = [string[]]@(Get-FakeRels); [Array]::Sort($fakeKeys, [StringComparer]::Ordinal)
Assert-Equal ".claude-accounts.json|.claude/projects/p/memory/s.md|.claude/settings.json" ($fakeKeys -join "|") "noms Drive = chemins relatifs, cache exclu"
Assert-Equal "PCA" (Get-FakeEntry ".claude/settings.json").Pc "PC d'origine en metadonnee"
Assert-Equal 1700000000 (Get-FakeEntry ".claude/settings.json").M "date en metadonnee"
Assert-True ($r.At -gt 0) "heure de la derniere synchro"
Assert-Equal $r.At ([long](Read-DriveConfig)["lastSync"]) "derniere synchro gardee dans la config"
Assert-Equal 0 (Invoke-DriveSync).Total "second passage sans changement : rien a faire"

Use-Pc "PCB"
Save-Registry @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" })
$r = Invoke-DriveSync
Assert-True $r.Ok ("PC neuf : synchro reussie " + $r.Error)
Assert-Equal 2 $r.Down "PC neuf : tout recu"
Assert-Equal 0 $r.Deleted "PC neuf : rien supprime"
Assert-Equal "a1" (Get-PcText ".claude/settings.json") "PC neuf : contenu recu"
Assert-Equal 1700000000 (ConvertTo-UnixSeconds ([IO.File]::GetLastWriteTimeUtc((Join-Path $script:HomeDir ".claude/settings.json")))) "PC neuf : date d'origine posee"
Assert-Equal 0 (Invoke-DriveSync).Total "PC neuf : base complete apres le premier passage"

Set-PcFile ".claude/settings.json" "b2" 1700000100
$r = Invoke-DriveSync
Assert-Equal 1 $r.Up "modification envoyee"
Use-Pc "PCA"
$r = Invoke-DriveSync
Assert-Equal 1 $r.Down "modification recue"
Assert-Equal "b2" (Get-PcText ".claude/settings.json") "contenu modifie recu"

Remove-Item -LiteralPath (Join-Path $script:HomeDir ".claude/projects/p/memory/s.md")
$r = Invoke-DriveSync
Assert-Equal 1 $r.Deleted "suppression propagee au Drive"
Assert-True (-not (Test-FakeFile ".claude/projects/p/memory/s.md")) "fichier mis a la corbeille du Drive"
Use-Pc "PCB"
$r = Invoke-DriveSync
Assert-Equal 1 $r.Deleted "suppression recue"
Assert-Null (Get-PcText ".claude/projects/p/memory/s.md") "fichier supprime localement"

Use-Pc "PCA"
Set-PcFile ".claude/settings.json" "a3" 1700000300
$null = Invoke-DriveSync
Use-Pc "PCB"
Set-PcFile ".claude/settings.json" "b3" 1700000200
$r = Invoke-DriveSync
Assert-Equal 1 $r.Conflicts "conflit detecte"
Assert-Equal "a3" (Get-PcText ".claude/settings.json") "conflit : la version la plus recente gagne"
Assert-Equal "b3" (Get-PcText ".claude/settings.json.conflit-PCB") "conflit : version perdante gardee a cote"
Assert-Equal 0 (Invoke-DriveSync).Total "copie de conflit jamais synchronisee"
Set-PcFile ".claude/settings.json" "b4" 1700000500
Use-Pc "PCA"
Set-PcFile ".claude/settings.json" "a4" 1700000400
$null = Invoke-DriveSync
Use-Pc "PCB"
$r = Invoke-DriveSync
Assert-Equal "b4" (Get-PcText ".claude/settings.json") "conflit : le local plus recent gagne"
Assert-Equal "a4" (Get-PcText ".claude/settings.json.conflit-PCA") "conflit : version distante gardee sous le nom de son PC"
Assert-Equal "b4" ((Get-FakeText ".claude/settings.json")) "conflit : gagnant local envoye"

Use-Pc "PCA"
foreach ($i in 1..25) { Set-PcFile (".claude/notes/n" + $i + ".md") ("n" + $i) }
$null = Invoke-DriveSync
Use-Pc "PCB"
$null = Invoke-DriveSync
Remove-Item -LiteralPath (Join-Path $script:HomeDir ".claude/notes") -Recurse -Force
$r = Invoke-DriveSync
Assert-True (-not $r.Ok) "garde-fou : synchro bloquee"
Assert-Equal (Get-ClmText "drive.scope.blocked" @(25)) $r.Error "garde-fou : message"
Assert-True (Test-FakeFile ".claude/notes/n1.md") "garde-fou : rien supprime"
$r = Invoke-DriveSync -Force
Assert-Equal 25 $r.Deleted "--force passe outre le garde-fou"

foreach ($i in 1..5) { Set-PcFile (".claude/lot/f" + $i + ".md") ("f" + $i) }
$ctl = [hashtable]::Synchronized(@{ Stop = $false; Progress = "" })
$script:StopCtl = $ctl
$script:StopAfter = 2
$r = Invoke-DriveSync $ctl
Assert-Equal 2 $r.Up "arret : fichiers deja envoyes"
Assert-Equal 3 $r.Left "arret : reste a faire"
Assert-Equal "2/5" $ctl.Progress "progression n/total"
Assert-Equal 3 (Invoke-DriveSync).Up "arret : base partielle sauvee, le reste part ensuite"

foreach ($i in 1..3) { Set-PcFile (".claude/tard/t" + $i + ".md") ("t" + $i) }
$before = [long](Read-DriveConfig)["lastSync"]
$r = Invoke-DriveSync $null 1
Assert-True $r.Ok "echeance depassee : pas une erreur"
Assert-True $r.Stopped "echeance depassee : analyse interrompue"
Assert-Equal 0 $r.Up "echeance depassee : rien envoye"
Assert-Equal 0 $r.At "echeance depassee : synchro pas complete"
Assert-Equal $before ([long](Read-DriveConfig)["lastSync"]) "echeance depassee : derniere synchro inchangee"
Assert-Equal (Get-ClmText "drive.msg.line" @((Get-ClmText "drive.msg.stopped"))) (Get-DriveSyncMsg $r) "echeance depassee : message"
$r = Invoke-DriveSync ([hashtable]::Synchronized(@{ Stop = $true; Progress = "" }))
Assert-True ($r.Stopped -and $r.Up -eq 0) "arret demande avant la fin de l'analyse : rien envoye"

$script:FailSend = @(".claude/tard/t1.md")
$r = Invoke-DriveSync
Assert-Equal 2 $r.Up "echec d'un fichier : les autres partent"
Assert-Equal 1 $r.Failed "echec d'un fichier compte"
Assert-Equal (Get-ClmText "drive.sync.failedFiles" @(1, " (.claude/tard/t1.md : panne reseau)")) $r.Error "echec d'un fichier : message"
foreach ($i in 1..4) { Set-PcFile (".claude/panne/p" + $i + ".md") ("p" + $i) }
$script:FailSend = @(".claude/panne/p1.md", ".claude/panne/p2.md", ".claude/panne/p3.md", ".claude/tard/t1.md")
$r = Invoke-DriveSync
Assert-Equal "panne reseau" $r.Error "trois echecs de suite : synchro arretee"
Assert-True (-not (Test-FakeFile ".claude/panne/p4.md")) "trois echecs de suite : reste non tente"
$script:FailSend = @()
$null = Invoke-DriveSync

$script:Fake["../evil.md"] = @{ Id = "evil"; Name = "../evil.md"; Md5 = "x"; M = 0; Pc = "X"; Bytes = [byte[]]@(65) }
$script:Fake[".autre/x.md"] = @{ Id = "autre"; Name = ".autre/x.md"; Md5 = "x"; M = 0; Pc = "X"; Bytes = [byte[]]@(65) }
$script:Fake[".claude/cache/y.bin"] = @{ Id = "cache"; Name = ".claude/cache/y.bin"; Md5 = "x"; M = 0; Pc = "X"; Bytes = [byte[]]@(65) }
$r = Invoke-DriveSync
Assert-Equal 0 $r.Total "noms Drive hors perimetre ignores"
Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:Sandbox "evil.md"))) "chemin qui remonte jamais ecrit"
(Remove-FakeFile "../evil.md"); (Remove-FakeFile ".autre/x.md"); (Remove-FakeFile ".claude/cache/y.bin")

$chromeFile = ".claude/outils/chrome-bidi/profils/c/Cookies"
$script:Fake[$chromeFile] = @{ Id = "chrome"; Name = $chromeFile; Md5 = "x"; M = 0; Pc = "X"; Bytes = [byte[]]@(65) }
Set-PcFile ".claude/outils/chrome-bidi/profils/c/Local State" "pc"
$st = Read-DriveState
$st.Files[$chromeFile] = @{ Md5 = "x"; M = 0; Size = 1; Id = "chrome" }
Save-DriveState $st
$r = Invoke-DriveSync
Assert-Equal "1 0 0 0" (@($r.Total, $r.Up, $r.Down, $r.Deleted) -join " ") "profil Chrome : oublie de la base, rien envoye, recu ni supprime"
Assert-True (-not (Read-DriveState).Files.ContainsKey($chromeFile)) "profil Chrome : retire de la base"
Assert-True (Test-FakeFile $chromeFile) "profil Chrome d'un autre PC : laisse sur le Drive"
Assert-Equal "pc" (Get-PcText ".claude/outils/chrome-bidi/profils/c/Local State") "profil Chrome : copie locale gardee"
(Remove-FakeFile $chromeFile)

if ($script:OsName -eq "Windows") {
  $fs = [IO.File]::Open((Join-Path $script:HomeDir ".claude/settings.json"), "Open", "ReadWrite", "None")
  try { $r = Invoke-DriveSync } finally { $fs.Dispose() }
  Assert-Equal 0 $r.Deleted "fichier verrouille : jamais pris pour supprime"
  Assert-True (Test-FakeFile ".claude/settings.json") "fichier verrouille : garde sur le Drive"
}

Assert-Equal (Get-ClmText "drive.msg.line" @((Get-ClmText "drive.msg.done" @(2, 1, 0, 1)))) (Get-DriveSyncMsg @{ Ok = $true; Error = ""; Up = 2; Down = 1; Deleted = 0; Conflicts = 1; Left = 0 }) "message de fin"
Assert-Equal ((Get-ClmText "drive.msg.line" @((Get-ClmText "drive.msg.done" @(0, 0, 0, 0)))) + ", " + (Get-ClmText "drive.msg.left" @(4))) (Get-DriveSyncMsg @{ Ok = $true; Error = ""; Up = 0; Down = 0; Deleted = 0; Conflicts = 0; Left = 4 }) "message avec reste"
Assert-Equal (Get-ClmText "drive.msg.line" @("panne")) (Get-DriveSyncMsg @{ Ok = $false; Error = "panne" }) "message d'erreur"
Restore-FakeDrive
. (Join-Path $bin "claude-drive-creds.ps1")
