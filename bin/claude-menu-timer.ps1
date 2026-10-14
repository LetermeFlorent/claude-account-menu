$script:RereadMs = 180000
$script:RereadJitterMs = 25000

function Format-Countdown {
  param([int]$Seconds)
  if ($Seconds -lt 60) { return "" + $Seconds + "s" }
  return "" + [math]::Floor($Seconds / 60) + "m" + ("{0:D2}" -f ($Seconds % 60)) + "s"
}

function Get-NextReadAt {
  param($E, [double]$Now, [long]$UnixNow = 0)
  if ($UnixNow -le 0) { $UnixNow = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
  $pause = [long]$E.U.LimitedUntil - $UnixNow
  if ($pause -gt 0) { return $Now + ($pause + 1) * 1000 }
  $wait = $script:RereadMs
  if ($null -ne $E.U.Age -and $null -eq $E.U.Error) { $wait = [math]::Max(0, $script:UsageCacheTtl - $E.U.Age) * 1000 }
  $at = $Now + $wait + [double]$E.Slot + (Get-Random -Maximum $script:RereadJitterMs)
  $E.Slot = 0
  return $at
}

function Get-EntryTimer {
  param($E, [bool]$Busy, [double]$Now, [long]$UnixNow = 0)
  if ($Busy) { return ,@("en pause", $script:Ink.Dim, $false) }
  if ($E.Pending -and -not $E.Seen) { return ,@("", $script:Ink.Dim, $false) }
  if ($E.Pending -or $E.Force -or $null -eq $E.NextAt) { return ,@("lecture...", $script:Ink.Dim, $false) }
  if ($UnixNow -le 0) { $UnixNow = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
  $at = Format-Countdown ([int][math]::Max(0, [math]::Ceiling(($E.NextAt - $Now) / 1000)))
  if ($null -ne $E.U.Error) { return ,@(("reessai " + $at), $script:Ink.Alert, $false) }
  if ([long]$E.U.LimitedUntil -gt $UnixNow) { return ,@(("pause API " + $at), $script:Levels["7d"][1], $false) }
  return ,@(("maj " + $at), $script:Ink.Dim, $false)
}

function Update-MenuTimers {
  param($State, [double]$Now, [long]$UnixNow = 0)
  $changed = $false
  foreach ($e in $State.Entries) {
    $t = Get-EntryTimer $e $State.Busy $Now $UnixNow
    if ($null -eq $e.Timer -or $t[0] -cne $e.Timer[0]) { $e.Timer = $t; $changed = $true }
  }
  $clock = Get-Date -Format "HH:mm"
  if ($clock -cne $State.Clock) { $State.Clock = $clock; $changed = $true }
  return $changed
}

function Get-ForcedReadMsg {
  param($E, [long]$UnixNow = 0)
  if ($UnixNow -le 0) { $UnixNow = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
  $head = "  " + $E.Acc.Label + " : "
  $pause = [long]$E.U.LimitedUntil - $UnixNow
  if ($pause -gt 0) { return ,@(($head + "l'API refuse la relecture, reessai dans " + (Format-Countdown $pause)), $script:Levels["7d"][1]) }
  if ($E.U.Error) { return ,@(($head + "relecture impossible, " + $E.U.Error), $script:Ink.Alert) }
  $pcts = "5h " + [int]$E.U.Pct5 + " %, 7j " + [int]$E.U.Pct7 + " %"
  if ($null -ne $E.U.Age) { return ,@(($head + "deja a jour, lu il y a " + (Format-Age $E.U.Age) + " (" + $pcts + ")"), $script:Ink.Dim) }
  return ,@(($head + "quotas relus a " + (Get-Date -Format "HH:mm:ss") + " (" + $pcts + ")"), $script:Levels["7d"][0])
}

function Complete-ForcedRead {
  param($State, $E)
  if (-not $E.Force) { return }
  $E.Force = $false
  $State.Msg = Get-ForcedReadMsg $E
}
