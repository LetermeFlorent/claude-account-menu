. (Join-Path $PSScriptRoot "fake-drive.ps1")
Use-Pc "PCL"
Save-Registry @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" })
$null = Invoke-DriveSync
$own = ".claude/outils/chrome-bidi/profils/c/Cookies"
$ownState = ".claude/outils/chrome-bidi/profils/c/Local State"
$other = ".claude/outils/chrome-bidi/profils/c/History"
$orphan = ".claude/projects/C--x/1f2e/subagents/agent-a.jsonl"
$script:Fake[$orphan] = @{ Id = "orphan"; Name = $orphan; Md5 = "x"; M = 0; Pc = ""; Bytes = [byte[]]@(65) }
$script:Fake[$own] = @{ Id = "own"; Name = $own; Md5 = "x"; M = 0; Pc = "PCL"; Bytes = [byte[]]@(65) }
$script:Fake[$ownState] = @{ Id = "own-state"; Name = $ownState; Md5 = "x"; M = 0; Pc = "PCL"; Bytes = [byte[]]@(65) }
$script:Fake[$other] = @{ Id = "other"; Name = $other; Md5 = "x"; M = 0; Pc = "PCM"; Bytes = [byte[]]@(65) }
Set-PcFile $own "local"
Assert-Equal 0 (Remove-OwnLeftovers (Get-DriveListing "F") "PCL" @{ Stop = $true } 0) "arret demande : rien retire du Drive"
$script:FakePresence["PCM.json"] = @{ Id = "pm"; Name = "PCM.json"; Props = @{ ".claude" = "0" } }
Assert-Equal 0 (Invoke-DriveSync).Deleted "un PC encore sur l'ancienne version : rien retire du Drive"
Assert-True $script:Fake.ContainsKey($own) "un PC encore sur l'ancienne version : copie gardee"
Assert-Equal ("" + $script:SyncFormat) $script:FakePresence["PCL.json"].Props["fmt"] "presence : version de synchro de ce PC annoncee"
$script:FakePresence["PCM.json"].Props["fmt"] = "" + $script:SyncFormat
$r = Invoke-DriveSync
Assert-Equal 3 $r.Deleted "profil Chrome envoye par ce PC et fichier sans PC : chaque fichier retire du Drive"
Assert-True (-not ($script:Fake.ContainsKey($own) -or $script:Fake.ContainsKey($ownState))) "profil Chrome de ce PC : mis a la corbeille du Drive"
Assert-True (-not $script:Fake.ContainsKey($orphan)) "fichier jamais synchronise sans PC : mis a la corbeille du Drive"
Assert-True $script:Fake.ContainsKey(".claude-accounts.json") "fichier hors profil envoye par ce PC : garde sur le Drive"
Assert-True $script:Fake.ContainsKey($other) "profil Chrome d'un autre PC : laisse a ce PC"
Assert-Equal "local" (Get-PcText $own) "profil Chrome : copie locale gardee"
Assert-Equal 0 (Invoke-DriveSync).Deleted "profil Chrome : retire une seule fois"
$script:Fake.Remove($other)
$script:FakePresence.Clear()
Restore-FakeDrive
. (Join-Path $bin "claude-drive-creds.ps1")
