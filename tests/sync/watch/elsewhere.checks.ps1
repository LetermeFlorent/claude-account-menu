$elseSaved = $script:DriveConfigPath
$script:DriveConfigPath = Join-Path $script:Sandbox "else-drive.json"
Save-DriveConfig @{ refreshToken = "r"; lastSync = 1700000500 }

$job = New-DriveJob $true 1700000000
Assert-True (-not (Step-DriveJob $job 5000)) "verrou libre : rien a redessiner"
$held = Open-MachineLock "drive"
Assert-True (-not (Step-DriveJob $job 5500)) "verrou regarde au plus une fois par seconde"
Assert-True (Step-DriveJob $job 6000) "synchro d'un autre processus vue"
Assert-Equal (Get-ClmText "drive.tag.syncing") (Get-DriveTag $job)[0] "synchro du veilleur dans l'en-tete"
Assert-True (-not (Step-DriveJob $job 7000)) "synchro toujours en cours : rien de neuf"
Close-MachineLock $held
Assert-True (Step-DriveJob $job 8000) "fin de la synchro de l'autre processus vue"
Assert-Equal 1700000500 $job.Last "heure de la synchro de l'autre processus"
Assert-True ((Get-DriveTag $job)[0] -match ('^' + (Get-ClmText "drive.tag.sync" @('\d\d:\d\d')) + '$')) "en-tete : heure de la derniere synchro"
Assert-Equal 0 $job.RetryAt "sans attente : pas de nouvel essai"

$held = Open-MachineLock "drive"
$job.Busy = $true
$job.RetryAt = 999999
Assert-True (Step-DriveJob $job 9000) "synchro en attente, verrou pris ailleurs"
Close-MachineLock $held
Assert-True (Step-DriveJob $job 10000) "verrou libre"
Assert-Equal "10000 True" ("" + $job.RetryAt + " " + $job.Busy) "synchro en attente relancee des que le verrou se libere"
$off = New-DriveJob $false 0
Assert-True (-not (Step-DriveJob $off 9000)) "Drive non connecte : pas de regard sur le verrou"

Remove-Item -LiteralPath $script:DriveConfigPath -Force
$script:DriveConfigPath = $elseSaved
