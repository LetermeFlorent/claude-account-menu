$script:LiveCheckMs = 2000

function Get-StatusStamp {
  param([string]$Path)
  try {
    $info = New-Object IO.FileInfo($Path)
    if (-not $info.Exists) { return "" }
    return "" + $info.LastWriteTimeUtc.Ticks + ":" + $info.Length
  } catch { return "" }
}

function Show-EntryUsage {
  param($E, [double]$Now)
  $p5 = [double]$E.U.Pct5
  $p7 = [double]$E.U.Pct7
  if ($E.Seen) {
    if ($E.T5.To -ne $p5) { Set-TweenTarget $E.T5 $p5 300 $Now }
    if ($E.T7.To -ne $p7) { Set-TweenTarget $E.T7 $p7 300 $Now }
  } else {
    $E.T5 = New-Tween 0 $p5 400 $Now
    $E.T7 = New-Tween 0 $p7 400 $Now
    $E.Seen = $true
  }
  Update-EntryView $E
}

function Set-LiveUsage {
  param($State, $E, $Bar, [double]$Now)
  if ($null -eq $Bar -or $Bar.At -le [long]$E.U.At) { return $false }
  $u = New-UsageRow $E.Acc $E.U.Email
  $u.Plan = $E.U.Plan
  $u.LimitedUntil = $E.U.LimitedUntil
  Copy-CacheEntry $Bar $u
  $u.At = $Bar.At
  $E.U = $u
  Show-EntryUsage $E $Now
  $paused = [long]$E.U.LimitedUntil -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  if (-not $E.Pending -and -not $E.Force -and -not $paused) { $E.NextAt = Get-NextReadAt $E $Now 0 $State.Jitter $State.PollSec }
  return $true
}

function Update-LiveUsage {
  param($State, [double]$Now)
  if ($null -ne $State.LiveAt -and $Now -lt $State.LiveAt) { return $false }
  $State.LiveAt = $Now + $script:LiveCheckMs
  $path = Get-StatusStatePath
  $stamp = Get-StatusStamp $path
  if ($stamp -ceq $State.LiveStamp) { return $false }
  $State.LiveStamp = $stamp
  $map = Read-StatusLines $path
  $changed = $false
  foreach ($e in $State.Entries) { if (Set-LiveUsage $State $e (Read-StatusUsage $e.Acc $map) $Now) { $changed = $true } }
  if ($changed) { $State.Dirty = $true }
  return $changed
}
