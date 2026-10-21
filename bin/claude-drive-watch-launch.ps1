. (Join-Path $PSScriptRoot "claude-drive-sessions.ps1")
$script:DriveWatchLockPath = Join-Path (Get-HomeDir) ".clm-drive-watch.lock"
$script:DriveWatcherScript = Join-Path $PSScriptRoot "claude-drive-watcher.ps1"
$script:DriveWatchSpawnWaitMs = 5000
$script:DriveWatchSpawnPollMs = 100
$script:UnixDetachCommand = 'if command -v setsid >/dev/null 2>&1; then setsid "$0" -NoProfile -NonInteractive -File "$1" </dev/null >/dev/null 2>&1 & else nohup "$0" -NoProfile -NonInteractive -File "$1" </dev/null >/dev/null 2>&1 & fi'

function Open-DriveWatchLock {
  try { return [IO.File]::Open($script:DriveWatchLockPath, "OpenOrCreate", "ReadWrite", "None") } catch { return $null }
}

function Test-DriveWatcherRunning {
  $fs = Open-DriveWatchLock
  if ($null -eq $fs) { return $true }
  $fs.Dispose()
  return $false
}

function Get-PowerShellPath {
  return (Get-Process -Id $PID).Path
}

function Start-HiddenWindowsProcess {
  param([string]$Exe, [string]$Script)
  $psi = New-Object Diagnostics.ProcessStartInfo
  $psi.FileName = $Exe
  $psi.Arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $Script + '"'
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $p = [Diagnostics.Process]::Start($psi)
  try { $p.PriorityClass = "BelowNormal" } catch {}
  $p.Dispose()
}

function Start-DetachedUnixProcess {
  param([string]$Exe, [string]$Script)
  $psi = New-Object Diagnostics.ProcessStartInfo "/bin/sh"
  foreach ($a in @("-c", $script:UnixDetachCommand, $Exe, $Script)) { $psi.ArgumentList.Add($a) }
  $psi.UseShellExecute = $false
  $p = [Diagnostics.Process]::Start($psi)
  $null = $p.WaitForExit($script:DriveWatchSpawnWaitMs)
  $p.Dispose()
}

function Start-DriveWatcher {
  if (Test-DriveWatcherRunning) { return $true }
  try {
    if ($script:OsName -eq "Windows") { Start-HiddenWindowsProcess (Get-PowerShellPath) $script:DriveWatcherScript }
    else { Start-DetachedUnixProcess (Get-PowerShellPath) $script:DriveWatcherScript }
  } catch { return $false }
  return $true
}

function Wait-DriveWatcher {
  param([string]$Ended)
  if (Test-DriveWatcherRunning) { return $true }
  if (-not (Start-DriveWatcher)) { return $false }
  $end = [DateTime]::UtcNow.AddMilliseconds($script:DriveWatchSpawnWaitMs)
  while ([DateTime]::UtcNow -lt $end) {
    if ((Test-DriveWatcherRunning) -or -not [IO.File]::Exists($Ended)) { return $true }
    [Threading.Thread]::Sleep($script:DriveWatchSpawnPollMs)
  }
  return $false
}
