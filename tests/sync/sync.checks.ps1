. (Join-Path $PSScriptRoot "fake-drive.ps1")
Use-Pc "PCA"
Save-Registry @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" })
Set-PcFile ".claude/settings.json" "a1" 1700000000
Set-PcFile ".claude/projects/p/s.jsonl" "s1"
Set-PcFile ".claude/cache/x.bin" "cache"
$r = Invoke-DriveSync
Assert-True $r.Ok ("premier envoi reussi " + $r.Error)
Assert-Equal 3 $r.Up "premier envoi : registre, reglages, conversation"
$fakeKeys = [string[]]@($script:Fake.Keys); [Array]::Sort($fakeKeys, [StringComparer]::Ordinal)
Assert-Equal ".claude-accounts.json|.claude/projects/p/s.jsonl|.claude/settings.json" ($fakeKeys -join "|") "noms Drive = chemins relatifs, cache exclu"
Assert-Equal "PCA" $script:Fake[".claude/settings.json"].Pc "PC d'origine en metadonnee"
Assert-Equal 1700000000 $script:Fake[".claude/settings.json"].M "date en metadonnee"
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

Remove-Item -LiteralPath (Join-Path $script:HomeDir ".claude/projects/p/s.jsonl")
$r = Invoke-DriveSync
Assert-Equal 1 $r.Deleted "suppression propagee au Drive"
Assert-True (-not $script:Fake.ContainsKey(".claude/projects/p/s.jsonl")) "fichier mis a la corbeille du Drive"
Use-Pc "PCB"
$r = Invoke-DriveSync
Assert-Equal 1 $r.Deleted "suppression recue"
Assert-Null (Get-PcText ".claude/projects/p/s.jsonl") "fichier supprime localement"

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
Assert-Equal "b4" ([Text.Encoding]::UTF8.GetString($script:Fake[".claude/settings.json"].Bytes)) "conflit : gagnant local envoye"

Use-Pc "PCA"
foreach ($i in 1..25) { Set-PcFile (".claude/notes/n" + $i + ".md") ("n" + $i) }
$null = Invoke-DriveSync
Use-Pc "PCB"
$null = Invoke-DriveSync
Remove-Item -LiteralPath (Join-Path $script:HomeDir ".claude/notes") -Recurse -Force
$r = Invoke-DriveSync
Assert-True (-not $r.Ok) "garde-fou : synchro bloquee"
Assert-Equal "synchro bloquee : 25 suppressions prevues, verifier puis lancer clm --sync --force" $r.Error "garde-fou : message"
Assert-True $script:Fake.ContainsKey(".claude/notes/n1.md") "garde-fou : rien supprime"
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
Assert-Equal 3 $r.Left "echeance depassee : tout reste a faire"
Assert-Equal 0 $r.At "echeance depassee : synchro pas complete"
Assert-Equal $before ([long](Read-DriveConfig)["lastSync"]) "echeance depassee : derniere synchro inchangee"

$script:FailSend = @(".claude/tard/t1.md")
$r = Invoke-DriveSync
Assert-Equal 2 $r.Up "echec d'un fichier : les autres partent"
Assert-Equal 1 $r.Failed "echec d'un fichier compte"
Assert-Equal "1 fichier(s) en echec, nouvel essai a la prochaine synchro" $r.Error "echec d'un fichier : message"
foreach ($i in 1..4) { Set-PcFile (".claude/panne/p" + $i + ".md") ("p" + $i) }
$script:FailSend = @(".claude/panne/p1.md", ".claude/panne/p2.md", ".claude/panne/p3.md", ".claude/tard/t1.md")
$r = Invoke-DriveSync
Assert-Equal "panne reseau" $r.Error "trois echecs de suite : synchro arretee"
Assert-True (-not $script:Fake.ContainsKey(".claude/panne/p4.md")) "trois echecs de suite : reste non tente"
$script:FailSend = @()
$null = Invoke-DriveSync

$script:Fake["../evil.md"] = @{ Id = "evil"; Name = "../evil.md"; Md5 = "x"; M = 0; Pc = "X"; Bytes = [byte[]]@(65) }
$script:Fake[".autre/x.md"] = @{ Id = "autre"; Name = ".autre/x.md"; Md5 = "x"; M = 0; Pc = "X"; Bytes = [byte[]]@(65) }
$script:Fake[".claude/cache/y.bin"] = @{ Id = "cache"; Name = ".claude/cache/y.bin"; Md5 = "x"; M = 0; Pc = "X"; Bytes = [byte[]]@(65) }
$r = Invoke-DriveSync
Assert-Equal 0 $r.Total "noms Drive hors perimetre ignores"
Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:Sandbox "evil.md"))) "chemin qui remonte jamais ecrit"
$script:Fake.Remove("../evil.md"); $script:Fake.Remove(".autre/x.md"); $script:Fake.Remove(".claude/cache/y.bin")

if ($script:OsName -eq "Windows") {
  $fs = [IO.File]::Open((Join-Path $script:HomeDir ".claude/settings.json"), "Open", "ReadWrite", "None")
  try { $r = Invoke-DriveSync } finally { $fs.Dispose() }
  Assert-Equal 0 $r.Deleted "fichier verrouille : jamais pris pour supprime"
  Assert-True $script:Fake.ContainsKey(".claude/settings.json") "fichier verrouille : garde sur le Drive"
}

$lock = [IO.File]::Open($script:DriveLockPath, "OpenOrCreate", "ReadWrite", "None")
try { $r = Invoke-DriveSync } finally { $lock.Dispose() }
Assert-Equal "une autre synchro Drive est en cours" $r.Error "verrou : deux synchros jamais en meme temps"

Assert-Equal "synchro Drive : 2 envoyes, 1 recus, 0 supprimes, 1 conflits" (Get-DriveSyncMsg @{ Ok = $true; Error = ""; Up = 2; Down = 1; Deleted = 0; Conflicts = 1; Left = 0 }) "message de fin"
Assert-Equal "synchro Drive : 0 envoyes, 0 recus, 0 supprimes, 0 conflits, 4 restants pour la prochaine synchro" (Get-DriveSyncMsg @{ Ok = $true; Error = ""; Up = 0; Down = 0; Deleted = 0; Conflicts = 0; Left = 4 }) "message avec reste"
Assert-Equal "synchro Drive : panne" (Get-DriveSyncMsg @{ Ok = $false; Error = "panne" }) "message d'erreur"
Restore-FakeDrive
. (Join-Path $bin "claude-drive-creds.ps1")
