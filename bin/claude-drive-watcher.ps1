if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-state-migrate.ps1")) { . (Join-Path $PSScriptRoot "claude-state-migrate.ps1") }
$null = Invoke-StateMigration
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-drive-watch.ps1")) { . (Join-Path $PSScriptRoot "claude-drive-watch.ps1") }
try { [Diagnostics.Process]::GetCurrentProcess().PriorityClass = "BelowNormal" } catch {}
do { Invoke-DriveWatch } while (-not (Test-ClmReplaced) -and (Test-WatchSessionsPending) -and -not (Test-DriveWatcherRunning) -and (Test-DriveConnected))
if ((Test-ClmReplaced) -and (Test-WatchSessionsPending) -and (Test-DriveConnected)) { $null = Start-DriveWatcher }
