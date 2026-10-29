if (-not (Test-Path Function:\Import-ClmModule)) { . (Join-Path $PSScriptRoot "claude-import.ps1") }
. Import-ClmModule claude-state-migrate
$null = Invoke-StateMigration
. Import-ClmModule claude-drive-watch
try { [Diagnostics.Process]::GetCurrentProcess().PriorityClass = "BelowNormal" } catch { Write-Verbose $_.Exception.Message }
do { Invoke-DriveWatch } while (-not (Test-ClmReplaced) -and (Test-WatchSessionsPending) -and -not (Test-DriveWatcherRunning) -and (Test-DriveConnected))
if ((Test-ClmReplaced) -and (Test-WatchSessionsPending) -and (Test-DriveConnected)) { $null = Start-DriveWatcher }
