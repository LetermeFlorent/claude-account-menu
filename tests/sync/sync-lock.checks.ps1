. (Join-Path $PSScriptRoot "fake-drive.ps1")
Use-Pc "PCL"
Save-Registry @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" })
Set-PcFile ".claude/settings.json" "l1" 1700000000
$driveStamp = Get-StatePath "drive.done"
$folderStamp = Get-StatePath "drive-folders.done"
[IO.File]::Delete($driveStamp)

$held = Open-MachineLock "drive"
try { $r = Invoke-DriveSync } finally { Close-MachineLock $held }
Assert-Equal "" $r.Error "verrou tenu : aucune erreur"
Assert-True $r.Busy "verrou tenu : synchro en attente"
Assert-True $r.Ok "verrou tenu : pas un echec"
Assert-Equal (Get-ClmText "drive.msg.line" @((Get-LeftToOtherClm))) (Get-DriveSyncMsg $r) "verrou tenu : message"
Assert-Equal 0 @(Get-FakeRels).Count "verrou tenu : rien envoye"

Write-LockDone "drive" ((Get-LockNow) + 60000)
$r = Invoke-DriveSync
Assert-True ($r.Ok -and $r.Shared) "fait par un autre clm : saute"
Assert-Equal 0 @(Get-FakeRels).Count "fait par un autre clm : rien envoye"
Assert-Equal (Get-ClmText "drive.msg.line" @((Get-ClmText "drive.sync.sharedText"))) (Get-DriveSyncMsg $r) "fait par un autre clm : message"
$r = Invoke-DriveSync -Force
Assert-True ($r.Ok -and -not $r.Shared) "-Force : synchro faite malgre la trace"
Assert-True ($r.Up -gt 0) "-Force : fichiers envoyes"

[IO.File]::Delete($driveStamp)
$before = Get-LockNow
Set-PcFile ".claude/settings.json" "l2" 1700000100
$r = Invoke-DriveSync
Assert-True ($r.Ok -and $r.Left -eq 0) "synchro propre"
Assert-True (Test-LockDoneSince "drive" $before) "synchro propre : trace ecrite"

Write-MachineStamp "drive-folders" "x"
Set-PcFile ".claude/settings.json" "l3" 1700000200
$script:FailSend = @(".claude/settings.json")
$r = Invoke-DriveSync
$script:FailSend = @()
Assert-True ($r.Error -ne "") "echec reel : erreur rendue"
Assert-True ([string]::IsNullOrEmpty((Read-MachineStamp "drive-folders" 60000))) "echec reel : controle des dossiers a refaire"

[IO.File]::Delete($driveStamp)
[IO.File]::Delete($folderStamp)
Restore-FakeDrive
