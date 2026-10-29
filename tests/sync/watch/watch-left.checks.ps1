. (Join-Path (Split-Path -Parent $PSScriptRoot) "fake-drive.ps1")
Use-Pc "PCWL"
Save-Registry @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" })
$leftFolders = ${function:Get-DriveFolders}

Set-DriveAuto $false
Set-Item -Path function:Get-DriveFolders -Value { throw $script:LeftToOtherClm }
$r = Invoke-WatchSync
Set-Item -Path function:Get-DriveFolders -Value $leftFolders
Assert-Equal "" $r.Error "veilleur, dossiers crees par un autre clm : aucune erreur"
Assert-True ($r.Ok -and $r.Busy) "veilleur, dossiers crees par un autre clm : nouvel essai plus tard"

$leftSession = Register-DriveSession @{ Dir = ".claude" }
Assert-True ((Get-WatchLiveDirs).ContainsKey(".claude")) "session ouverte : compte vu comme ouvert"
$null = Close-DriveSession $leftSession
Assert-True (-not (Get-WatchLiveDirs).ContainsKey(".claude")) "session fermee : compte plus vu comme ouvert"
foreach ($s in @(Read-DriveSessions)) { [IO.File]::Delete($s.Path) }

Set-DriveAuto $true
$exitHeld = Open-MachineLock "drive"
$exitStart = Get-LockNow
try { $exitShown = Sync-DriveAfterExit @{ Dir = ".claude"; Label = "compte1" } ((Get-LockNow) + 700) *>&1 | Out-String } finally { Close-MachineLock $exitHeld }
Assert-True ((Get-LockNow) - $exitStart -ge 600) "sortie, synchro d'un autre clm : attente jusqu'a la limite"
Assert-True ($exitShown -notmatch "Drive :|erreur|echec|en cours") ("sortie, synchro d'un autre clm : aucun avertissement " + $exitShown)

Restore-FakeDrive
