. (Join-Path (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "fakes") "fake-drive.ps1")
$watchFaked = @("Invoke-DriveSync", "Sync-DriveCredentials", "Test-DriveFilesChanged", "Set-DrivePresence")
$watchSaved = @{}
foreach ($n in $watchFaked) { $watchSaved[$n] = (Get-Item ("function:" + $n)).ScriptBlock }
$watchSavedTick = $script:DriveWatchTickMs
$script:DriveWatchTickMs = 0
$watchSavedPoll = $script:DriveWatchSessionPollMs
$script:DriveWatchSessionPollMs = 0
$script:WatchCalls = New-Object 'System.Collections.Generic.List[string]'
$script:WatchResult = $null
$script:WatchRemote = $false

function Invoke-DriveSync { param($Ctl, [long]$DeadlineMs, [switch]$Force) $script:WatchCalls.Add("sync"); return $script:WatchResult }
function Sync-DriveCredentials { param($Folders, $Accs) $script:WatchCalls.Add("creds"); return 0 }
function Test-DriveFilesChanged { param($Folders, [string]$Pc) $script:WatchCalls.Add("changes"); return $script:WatchRemote }
function Set-DrivePresence { param($Acc, [bool]$Open) $script:WatchCalls.Add("presence " + $Acc.Dir + " " + $Open) }

function Set-WatchResult {
  param([string]$Message = "", [bool]$Busy = $false)
  $script:WatchResult = New-SyncResult
  $script:WatchResult.Ok = -not $Message
  $script:WatchResult.Error = $Message
  $script:WatchResult.Busy = $Busy
}

function Get-WatchCalls {
  $t = $script:WatchCalls -join ","
  $script:WatchCalls.Clear()
  return $t
}

Use-Pc "PCW"
Save-Registry @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" })
Set-WatchResult
$st = New-WatchState (Get-WatchNow)
Assert-True (-not (Step-DriveWatch $st)) "aucune session : veilleur arrete"

$session = Register-DriveSession @{ Dir = ".claude" }
Assert-True (Step-DriveWatch $st) "session ouverte : veilleur actif"
Assert-Equal "" (Get-WatchCalls) "rien a faire tout de suite"
$stepShaFn = (Get-Item "function:Get-ClmSha").ScriptBlock
function Get-ClmSha { param([string]$Dir = "") return "nouvelle" }
$script:ClmLoadedSha = "ancienne"
Assert-True (-not (Step-DriveWatch $st)) "clm mis a jour : veilleur arrete pour repartir"
Assert-Equal "" (Get-WatchCalls) "clm mis a jour : aucune synchro par l'ancien code"
Set-Item "function:Get-ClmSha" $stepShaFn
$script:ClmLoadedSha = Get-ClmSha
$st.RemoteAt = 0
$script:WatchRemote = $true
Assert-True (Step-DriveWatch $st) "regard sur le Drive"
Assert-Equal "creds,changes" (Get-WatchCalls) "regard : identifiants puis nouveautes du Drive"
Assert-True $st.Due "nouveaute sur le Drive : synchro prevue"
Assert-True ($null -ne $st.Fs) "surveillance des fichiers lancee"
$null = Step-DriveWatch $st
Assert-Equal "sync" (Get-WatchCalls) "nouveaute : synchro"
Assert-True (-not $st.Due) "synchro faite"

$null = Close-DriveSession $session
$null = Step-DriveWatch $st
Assert-Equal "sync,presence .claude False" (Get-WatchCalls) "sortie : derniere synchro puis presence retiree"
Assert-Equal 0 @(Read-DriveSessions).Count "sortie : session effacee"
Assert-True (-not (Step-DriveWatch $st)) "plus de session : veilleur arrete"

$session = Register-DriveSession @{ Dir = ".claude" }
$null = Close-DriveSession $session
Set-WatchResult "panne"
$st = New-WatchState (Get-WatchNow)
$null = Step-DriveWatch $st
Assert-Equal "sync" (Get-WatchCalls) "sortie en panne : pas de presence retiree"
Assert-Equal 1 @(Read-DriveSessions).Count "sortie en panne : session gardee"
$st.RetryAt = 0
$st.EndedSince = 1
$null = Step-DriveWatch $st
Assert-Equal "sync,presence .claude False" (Get-WatchCalls) "panne depuis 10 min : session fermee"

$session = Register-DriveSession @{ Dir = ".claude" }
$null = Close-DriveSession $session
Set-WatchResult
Save-DriveConfig @{ refreshToken = "r"; pc = "PCW"; auto = $false }
$st.RetryAt = 0
$null = Step-DriveWatch $st
Assert-Equal "creds,presence .claude False" (Get-WatchCalls) "synchro auto coupee : identifiants seulement"

$session = Register-DriveSession @{ Dir = ".claude" }
Save-DriveConfig @{ pc = "PCW" }
$st.RemoteAt = 0
Assert-True (-not (Step-DriveWatch $st)) "Drive deconnecte : veilleur arrete"
Assert-Equal "" (Get-WatchCalls) "Drive deconnecte : rien envoye"
Save-DriveConfig @{ refreshToken = "r"; pc = "PCW" }

$watchLog = Join-Path $script:DriveSessionDir $script:DriveWatchLogName
[IO.File]::Delete($watchLog)
$lock = Open-MachineLock "drive"
$st.RemoteAt = 0
$null = Step-DriveWatch $st
Assert-Equal "creds" (Get-WatchCalls) "verrou Drive pris : identifiants quand meme"
$st.RemoteAt = 0
$checkErr = ""
try { Invoke-WatchCheck $st } catch { $checkErr = $_.Exception.Message }
Close-MachineLock $lock
Assert-Equal "" $checkErr "verrou Drive pris : regard sans erreur"
$watchText = ""
if ([IO.File]::Exists($watchLog)) { $watchText = [IO.File]::ReadAllText($watchLog) }
Assert-True ($watchText -notmatch "laissee a un autre clm|en cours|check :") ("verrou Drive pris : rien dans le journal du veilleur " + $watchText)
$null = Get-WatchCalls
$null = Close-DriveSession $session
Set-WatchResult "" $true
$null = Step-DriveWatch $st
Assert-Equal "sync" (Get-WatchCalls) "synchro occupee a la sortie"
Assert-Equal 1 @(Read-DriveSessions).Count "synchro occupee : session gardee"
Assert-True ($st.RetryAt -gt (Get-WatchNow)) "synchro occupee : nouvel essai plus tard"
Stop-WatchFs $st.Fs
foreach ($p in @(Read-DriveSessions)) { [IO.File]::Delete($p.Path) }

$wl = Open-MachineLock "drive-watch"
Assert-True (Test-DriveWatcherRunning) "veilleur deja lance reconnu"
$session = Register-DriveSession @{ Dir = ".claude" }
Invoke-DriveWatch
Assert-Equal "" (Get-WatchCalls) "second veilleur : s'arrete tout de suite"
Close-MachineLock $wl
Assert-True (-not (Test-DriveWatcherRunning)) "aucun veilleur reconnu"
Assert-True (Test-WatchSessionsPending) "session ouverte en attente d'un veilleur"
$null = Close-DriveSession $session
Set-WatchResult
Invoke-DriveWatch
Assert-Equal "sync,presence .claude False" (Get-WatchCalls) "veilleur complet : derniere synchro puis arret"
Assert-True (-not (Test-WatchSessionsPending)) "plus rien en attente"
Assert-Equal 0 @(Get-EventSubscriber | Where-Object { $_.SourceIdentifier.StartsWith($script:DriveWatchPrefix) }).Count "surveillance arretee"

foreach ($n in $watchFaked) { Set-Item ("function:" + $n) $watchSaved[$n] }
$script:DriveWatchTickMs = $watchSavedTick
$script:DriveWatchSessionPollMs = $watchSavedPoll
Restore-FakeDrive
. (Join-Path $bin "drive/core/claude-drive-creds.ps1")
