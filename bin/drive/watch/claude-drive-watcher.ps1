if (-not (Test-Path Function:\Import-ClmModule)) { . (Join-Path $PSScriptRoot "../../claude-import.ps1") }
$script:WatcherStamp = Read-ClmStamp
if ($script:WatcherStamp -ceq $script:ClmInstallingStamp) { exit 0 }
try { . Import-ClmModule claude-state-migrate } catch { if (Test-ClmStampSteady $script:WatcherStamp) { throw } }
if (-not (Test-ClmStampSteady $script:WatcherStamp)) { exit 0 }
$null = Invoke-StateMigration
try { . Import-ClmModule claude-drive-watch } catch { if (Test-ClmStampSteady $script:WatcherStamp) { throw } }
if (-not (Test-ClmStampSteady $script:WatcherStamp)) { exit 0 }
try { [Diagnostics.Process]::GetCurrentProcess().PriorityClass = "BelowNormal" } catch { Write-Verbose $_.Exception.Message }
do { Invoke-DriveWatch } while (-not (Test-ClmReplaced) -and (Test-WatchSessionsPending) -and -not (Test-DriveWatcherRunning) -and (Test-DriveConnected))
if ((Test-ClmReplaced) -and (Test-WatchSessionsPending) -and (Test-DriveConnected)) { $null = Start-DriveWatcher }
