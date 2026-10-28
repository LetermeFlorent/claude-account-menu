. (Join-Path $PSScriptRoot "fake-drive.ps1")
Use-Pc "PCL"
Save-Registry @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" })
$null = Invoke-DriveSync
$own = ".claude/outils/chrome-bidi/profils/c/Cookies"
$ownState = ".claude/outils/chrome-bidi/profils/c/Local State"
$other = ".claude/outils/chrome-bidi/profils/c/History"
$hidden = ".claude/skills/.trash/vieux/SKILL.md"
$hiddenOther = ".claude/skills/.trash/autre.md"
$unchecked = ".claude/skills/decoche/SKILL.md"
$orphan = ".claude/projects/C--x/1f2e/subagents/agent-a.jsonl"
Add-FakeSealed $orphan "orphan" "A" 0 ""
Add-FakeSealed $own "own" "A" 0 "PCL"
Add-FakeSealed $ownState "own-state" "A" 0 "PCL"
Add-FakeSealed $other "other" "A" 0 "PCM"
Add-FakeSealed $hidden "hidden" "A" 0 "PCL"
Add-FakeSealed $hiddenOther "hidden-other" "A" 0 "PCM"
Add-FakeSealed $unchecked "unchecked" "A" 0 "PCL"
$null = Update-SyncChoice { param($c) Set-ChoiceCheck $c "skills" "decoche" $false $true }
Set-PcFile $own "local"
Set-PcFile $hidden "local"
Assert-Equal 0 (Remove-OwnLeftovers (Get-DriveListing "F") "PCL" @(Get-SyncPatterns @(Get-Accounts)) @{ Stop = $true } 0) "arret demande : rien retire du Drive"
$script:FakePresence["PCM.json"] = @{ Id = "pm"; Name = "PCM.json"; Props = @{ ".claude" = "0"; "fmt" = "3" } }
Assert-Equal 0 (Invoke-DriveSync).Deleted "un PC encore sur l'ancienne version : rien retire du Drive"
Assert-True (Test-FakeFile $own) "un PC encore sur l'ancienne version : copie gardee"
Assert-Equal ("" + $script:SyncFormat) $script:FakePresence["PCL.json"].Props["fmt"] "presence : version de synchro de ce PC annoncee"
$script:FakePresence["PCM.json"].Props["fmt"] = "" + $script:SyncFormat
$r = Invoke-DriveSync
Assert-Equal 4 $r.Deleted "profil Chrome et dossier masque des skills envoyes par ce PC, fichier sans PC : chaque fichier retire du Drive"
Assert-True (-not (Test-FakeFile $hidden)) "dossier masque des skills envoye par ce PC : mis a la corbeille du Drive"
Assert-True (Test-FakeFile $hiddenOther) "dossier masque des skills d'un autre PC : laisse a ce PC"
Assert-True (Test-FakeFile $unchecked) "skill decoche sur ce PC : garde sur le Drive pour les autres PC"
Assert-Equal "local" (Get-PcText $hidden) "dossier masque des skills : copie locale gardee"
Assert-True (-not ((Test-FakeFile $own) -or (Test-FakeFile $ownState))) "profil Chrome de ce PC : mis a la corbeille du Drive"
Assert-True (-not (Test-FakeFile $orphan)) "fichier jamais synchronise sans PC : mis a la corbeille du Drive"
Assert-True (Test-FakeFile ".claude-accounts.json") "fichier hors profil envoye par ce PC : garde sur le Drive"
Assert-True (Test-FakeFile $other) "profil Chrome d'un autre PC : laisse a ce PC"
Assert-Equal "local" (Get-PcText $own) "profil Chrome : copie locale gardee"
Assert-Equal 0 (Invoke-DriveSync).Deleted "profil Chrome : retire une seule fois"
(Remove-FakeFile $other)
(Remove-FakeFile $hiddenOther)
(Remove-FakeFile $unchecked)
$null = Update-SyncChoice { param($c) Set-ChoiceCheck $c "skills" "decoche" $true $true }
$script:FakePresence.Clear()
Restore-FakeDrive
. (Join-Path $bin "claude-drive-creds.ps1")
