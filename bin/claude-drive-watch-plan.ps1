$script:DriveWatchTickMs = 1000
$script:DriveWatchQuietMs = 2000
$script:DriveWatchGapMs = 30000
$script:DriveWatchRemoteMs = 30000
$script:DriveWatchBlindMs = 60000
$script:DriveWatchBusyRetryMs = 5000
$script:DriveWatchFailRetryMs = 60000
$script:DriveWatchGiveUpMs = 600000
$script:DriveWatchGone = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)

function Get-WatchNow {
  return [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
}

function New-WatchState {
  param([long]$Now)
  return @{ Live = 0; LiveDirs = @{}; Ended = @{}; EndedSince = [long]0; LocalFirst = [long]0; LocalAt = [long]0; PassAt = [long]0; RemoteAt = $Now; RetryAt = [long]0; Due = $false; Fs = $null }
}

function Add-WatchLocalChange {
  param($St, [long]$Now)
  if ($St.LocalFirst -eq 0) { $St.LocalFirst = $Now }
  $St.LocalAt = $Now
}

function Read-WatchSessions {
  return @(Read-DriveSessions | Where-Object { -not $script:DriveWatchGone.Contains($_.Path) })
}

function Test-WatchSessionsPending {
  foreach ($s in @(Read-WatchSessions)) { if ($s.Ended -or (Test-SessionAlive $s)) { return $true } }
  return $false
}

function Update-WatchSessions {
  param($St, [long]$Now)
  $live = 0
  $dirs = @{}
  foreach ($s in @(Read-WatchSessions)) {
    if (-not $s.Ended -and (Test-SessionAlive $s)) { $live++; $dirs[$s.Dir] = $true; continue }
    if ($St.Ended.ContainsKey($s.Path)) { continue }
    $St.Ended[$s.Path] = $s.Dir
    if ($St.EndedSince -eq 0) { $St.EndedSince = $Now }
  }
  $St.Live = $live
  $St.LiveDirs = $dirs
}

function Test-WatchLocalDue {
  param($St, [long]$Now)
  if ($St.LocalFirst -eq 0 -or $Now - $St.PassAt -lt $script:DriveWatchGapMs) { return $false }
  return $Now - $St.LocalAt -ge $script:DriveWatchQuietMs -or $Now - $St.LocalFirst -ge $script:DriveWatchGapMs
}

function Test-WatchBlindDue {
  param($St, [long]$Now)
  return $null -ne $St.Fs -and $St.Fs.Blind -and $Now - $St.PassAt -ge $script:DriveWatchBlindMs
}

function Get-DriveWatchAction {
  param($St, [long]$Now)
  if ($Now -lt $St.RetryAt) { return "" }
  if ($St.Ended.Count -gt 0) { return "final" }
  if ($St.Due -or (Test-WatchLocalDue $St $Now) -or (Test-WatchBlindDue $St $Now)) { return "pass" }
  if ($Now - $St.RemoteAt -ge $script:DriveWatchRemoteMs) { return "check" }
  return ""
}

function Test-WatchActive {
  param($St)
  return $St.Live -gt 0 -or $St.Ended.Count -gt 0
}

function Test-WatchResultClean {
  param($Result)
  return -not $Result.Error -and $Result.Left -eq 0 -and -not $Result.Stopped
}

function Complete-WatchPass {
  param($St, $Result, [bool]$Final, [long]$Now)
  if ($Result.Busy) { $St.RetryAt = $Now + $script:DriveWatchBusyRetryMs; return $false }
  $clean = Test-WatchResultClean $Result
  $St.Due = -not $clean
  $St.RetryAt = 0
  if (-not $clean) { $St.RetryAt = $Now + $script:DriveWatchFailRetryMs }
  $St.LocalFirst = 0
  $St.LocalAt = 0
  $St.PassAt = $Now
  $St.RemoteAt = $Now
  return $Final -and ($clean -or $Now - $St.EndedSince -ge $script:DriveWatchGiveUpMs)
}

function Get-WatchClosedDirs {
  param($St)
  $out = New-Object 'System.Collections.Generic.List[string]'
  foreach ($dir in @($St.Ended.Values)) {
    if ($dir -and -not $St.LiveDirs.ContainsKey($dir) -and -not $out.Contains($dir)) { $out.Add($dir) }
  }
  return $out.ToArray()
}
