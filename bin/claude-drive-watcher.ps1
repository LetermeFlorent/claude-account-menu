if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-drive-watch.ps1")) { . (Join-Path $PSScriptRoot "claude-drive-watch.ps1") }
try { [Diagnostics.Process]::GetCurrentProcess().PriorityClass = "BelowNormal" } catch {}
do { Invoke-DriveWatch } while ((Test-WatchSessionsPending) -and -not (Test-DriveWatcherRunning) -and (Test-DriveConnected))
