. (Join-Path (Split-Path -Parent $PSScriptRoot) "fake-drive.ps1")
$ssOne = @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" })
$ssPlain = "texte-clair-de-migration"
$ssOther = New-SyncKeys ([byte[]](100..131)) ([byte[]](1..16)) 600000

function Add-FakePlain {
  param([string]$Rel, [string]$Id, [string]$Text)
  $b = [Text.Encoding]::UTF8.GetBytes($Text)
  $script:Fake[$Rel] = @{ Id = $Id; Name = $Rel; Md5 = (Get-FakeMd5 $b); M = 1700000000; Pc = "PCB"; Exp = 0; Props = @{ m = "1700000000"; pc = "PCB" }; Bytes = $b }
}

function Start-SealedPc {
  param([string]$Pc)
  Use-Pc $Pc
  Save-Registry $ssOne
}

Start-SealedPc "PA"
Set-PcFile ".claude/m.md" $ssPlain
Add-FakePlain ".claude/m.md" "pm" $ssPlain
$null = Send-FakePresence "OLD.json" ([Text.Encoding]::UTF8.GetBytes("{}")) @{ fmt = "4" }
$r = Invoke-DriveSync
Assert-True ($r.Ok -and $r.Failed -eq 0) ("migration : synchro sans echec " + $r.Error)
Assert-True $script:Fake.ContainsKey($script:SealedPrefix + ".claude/m.md") "migration : fichier en clair renvoye chiffre"
Assert-Equal $ssPlain (Get-FakeText ".claude/m.md") "migration : contenu chiffre relu"
Assert-True (-not ([Text.Encoding]::UTF8.GetString($script:Fake[$script:SealedPrefix + ".claude/m.md"].Bytes)).Contains($ssPlain)) "migration : contenu illisible sur le Drive"
Assert-True $script:Fake.ContainsKey(".claude/m.md") "migration : copie en clair gardee tant qu'un PC est en retard"
Assert-Equal "OLD" ($r.Late -join ",") "migration : PC en retard nomme"
Assert-True ((Get-DriveSyncMsg $r).Contains("PC sur une ancienne version de clm : OLD")) "migration : PC en retard dans le message"
$script:FakePresence["OLD.json"].Props["fmt"] = ("" + $script:SyncFormat)
$r = Invoke-DriveSync
Assert-True (-not $script:Fake.ContainsKey(".claude/m.md")) "migration : copie en clair retiree quand tous les PC sont a jour"
Assert-True $script:Fake.ContainsKey($script:SealedPrefix + ".claude/m.md") "migration : copie chiffree gardee"
Assert-Equal 0 $r.Late.Count "migration : plus aucun PC en retard"

Start-SealedPc "PB"
foreach ($i in 1..4) { Add-FakePlain (".claude/p" + $i + ".md") ("pp" + $i) "clair" }
Add-FakeSealed ".claude/z.md" "zz" "fin"
$r = Invoke-DriveSync
foreach ($i in 1..4) { Assert-Null (Get-PcText (".claude/p" + $i + ".md")) ("fichier en clair " + $i + " jamais ecrit") }
Assert-Equal 4 $r.Failed "fichiers en clair comptes en echec"
Assert-Equal 4 $r.Refused.Count "fichiers en clair notes comme refuses"
Assert-True ((Get-DriveSyncMsg $r).Contains("refuses : .claude/p")) "fichiers refuses nommes dans le message"
Assert-Equal $ssPlain (Get-PcText ".claude/m.md") "fichier chiffre recu malgre les refus"
Assert-Equal "fin" (Get-PcText ".claude/z.md") "refus en serie : la synchro continue"
Assert-True $script:Fake.ContainsKey(".claude/p1.md") "fichier en clair refuse laisse sur le Drive"
foreach ($i in 1..4) { Remove-FakeFile (".claude/p" + $i + ".md") }

Start-SealedPc "PT"
Add-FakeSealed ".claude/t.md" "tt" "secret"
$tb = $script:Fake[$script:SealedPrefix + ".claude/t.md"].Bytes
$tb[$tb.Length - 40] = $tb[$tb.Length - 40] -bxor 1
Add-FakeSealed ".claude/r1.md" "rr" "autre"
$moved = $script:Fake[$script:SealedPrefix + ".claude/r1.md"]
$script:Fake.Remove($script:SealedPrefix + ".claude/r1.md")
$moved.Name = $script:SealedPrefix + ".claude/r2.md"
$script:Fake[$moved.Name] = $moved
Add-FakeSealed ".claude/w.md" "ww" "etranger" -Keys $ssOther
$r = Invoke-DriveSync
Assert-Null (Get-PcText ".claude/t.md") "fichier chiffre modifie : jamais ecrit"
Assert-Null (Get-PcText ".claude/r2.md") "fichier chiffre renomme : jamais ecrit"
Assert-Null (Get-PcText ".claude/w.md") "fichier chiffre avec une autre phrase : jamais ecrit"
Assert-Equal ".claude/r2.md,.claude/t.md,.claude/w.md" ((@($r.Refused) | Sort-Object) -join ",") "modifie, renomme et autre phrase refuses"
Assert-Equal $ssPlain (Get-PcText ".claude/m.md") "fichiers sains recus a cote des refus"
foreach ($rel in ".claude/t.md", ".claude/r2.md", ".claude/w.md") { Remove-FakeFile $rel }

$null = Send-FakePresence "AUTRE.json" (Protect-SyncBytes $ssOther "presence/AUTRE.json" ([Text.Encoding]::UTF8.GetBytes("{}"))) @{ fmt = ("" + $script:SyncFormat); k = $ssOther.Id }
$r = Invoke-DriveSync
Assert-True ($r.Ok -and $r.Failed -eq 0) "fiche de PC d'une autre phrase : ignoree sans echec"
$null = Send-FakePresence "FAUX.json" ([Text.Encoding]::UTF8.GetBytes('{"mcp": {}, "erased": {}}')) @{ fmt = ("" + $script:SyncFormat); k = $script:TestSyncKeys.Id }
$r = Invoke-DriveSync
Assert-True ($r.Failed -ge 1 -and @($r.Refused) -contains "presence/FAUX.json") "fiche de PC en clair : refusee"
$script:FakePresence.Remove("FAUX.json")
$script:FakePresence.Remove("AUTRE.json")

Start-SealedPc "PK"
$null = Publish-SyncKeyFile (Get-DriveFolders) $ssOther ""
Set-PcFile ".claude/k.md" "local"
$r = Invoke-DriveSync
Assert-Equal (Get-ClmText "sync.key.changed") $r.Error "phrase changee ailleurs : synchro arretee"
Assert-True (-not (Test-FakeFile ".claude/k.md")) "phrase changee ailleurs : rien envoye"
$script:FakeRootFiles.Clear()

Start-SealedPc "PN"
Remove-SyncKeys
Set-PcFile ".claude/n.md" "local"
$ssSaved = @(${function:Read-SyncPassText}, ${function:Get-DriveFolders})
$script:SsPrompts = 0
$script:SsNet = 0
Set-Item -Path function:Read-SyncPassText -Value { $script:SsPrompts++; return "" }
Set-Item -Path function:Get-DriveFolders -Value { $script:SsNet++; return & $ssSaved[1] }
$r = Invoke-DriveSync
$fresh = Receive-DriveCredential $ssOne[0]
Send-DriveCredential $ssOne[0]
Set-Item -Path function:Read-SyncPassText -Value $ssSaved[0]
Set-Item -Path function:Get-DriveFolders -Value $ssSaved[1]
Assert-Equal (Get-ClmText "sync.key.missing") $r.Error "sans phrase : pas de synchro"
Assert-True ((Get-DriveSyncMsg $r).Contains("clm --sync-key")) "sans phrase : message qui dit quoi faire"
Assert-Null $fresh "sans phrase : aucun jeton recu"
Assert-Equal 0 $script:SsPrompts "sans phrase : aucune question posee hors du menu"
Assert-Equal 0 $script:SsNet "sans phrase : aucun appel au Drive"
Assert-True (-not (Test-FakeFile ".claude/n.md")) "sans phrase : rien envoye"
Restore-FakeDrive
. (Join-Path $bin "claude-drive-creds.ps1")
