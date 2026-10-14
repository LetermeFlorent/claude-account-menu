function Get-MsgRow {
  param($State, [int]$W, [double]$Now)
  if ($null -ne $script:UiProgress) { return ,(Get-ProgressRow $W $Now) }
  $r = New-Row
  $r.Add(@($State.Msg[0], $State.Msg[1], $true))
  return ,$r
}

function Format-Countdown {
  param([int]$Seconds)
  if ($Seconds -lt 60) { return "" + $Seconds + "s" }
  return "" + [math]::Floor($Seconds / 60) + "m" + ("{0:D2}" -f ($Seconds % 60)) + "s"
}

function Get-AccountsText {
  param($Labels)
  if ($Labels.Count -gt 1) { return "" + $Labels.Count + " comptes" }
  return $Labels[0]
}

function Get-UpdateSeg {
  param($State, [double]$Now, [long]$UnixNow = 0)
  if ($State.Busy) { return ,@("maj en pause", $script:Ink.Dim, $false) }
  if ($null -ne $State.Loader -or $null -eq $State.NextAt) { return ,@("maj en cours", $script:Ink.Dim, $false) }
  if ($UnixNow -le 0) { $UnixNow = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
  $s = [int][math]::Max(0, [math]::Ceiling(($State.NextAt - $Now) / 1000))
  $bad = @(foreach ($e in $State.Entries) { if ($null -ne $e.U.Error) { $e.U.Label } })
  if ($bad.Count -gt 0) { return ,@(("maj en echec (" + (Get-AccountsText $bad) + "), reessai dans " + (Format-Countdown $s)), $script:Ink.Alert, $false) }
  $limited = @(foreach ($e in $State.Entries) { if ([long]$e.U.LimitedUntil -gt $UnixNow) { $e.U } })
  if ($limited.Count -eq 0) { return ,@(("maj dans " + (Format-Countdown $s)), $script:Ink.Dim, $false) }
  $first = ($limited | Measure-Object -Property LimitedUntil -Minimum).Minimum
  $wait = [int][math]::Max($s, $first - $UnixNow)
  $who = Get-AccountsText @($limited | ForEach-Object { $_.Label })
  return ,@(("API limitee (" + $who + "), reessai dans " + (Format-Countdown $wait)), $script:Levels["7d"][1], $false)
}

function Get-MenuHeaderRow {
  param($State, [int]$W, [double]$Now)
  $r = Get-HeaderRow "Comptes Claude Code" $W
  Add-RightSegs $r ($W - 2) @((Get-UpdateSeg $State $Now), @(("  " + (Get-Date -Format "HH:mm")), $script:Ink.Dim, $false))
  return ,$r
}

function Update-MenuHead {
  param($State, [double]$Now)
  $t = (Get-UpdateSeg $State $Now)[0] + (Get-Date -Format "HH:mm")
  if ($t -ceq $State.Head) { return $false }
  $State.Head = $t
  return $true
}

function Get-SimpleRows {
  param($State, $L, [int]$Top, [int]$Last, [double]$Now)
  $rows = New-Object 'System.Collections.Generic.List[object]'
  $rows.Add((Get-HeaderRow "Comptes Claude Code" $L.W))
  for ($i = $Top; $i -lt $Last; $i++) {
    $e = $State.Entries[$i]
    $u = $e.U
    $r = New-Row
    $mark = "   "
    if ($i -eq $State.Sel) { $mark = " " + $script:Mark + " " }
    $r.Add(@($mark, $script:Levels["5h"][0], $false))
    $r.Add(@(("" + ($i + 1) + "  " + $u.Label + "  "), $script:Ink.Text, ($i -eq $State.Sel)))
    if ($null -ne $u.Error) { $r.Add(@(("" + $u.Error), $script:Ink.Alert, $false)) }
    elseif ($e.Pending -and -not $e.Seen) { $r.Add(@("lecture...", $script:Ink.Dim, $false)) }
    else { $r.Add(@(("5h " + [int]$u.Pct5 + "%  7d " + [int]$u.Pct7 + "%"), $script:Ink.Dim, $false)) }
    $rows.Add($r)
  }
  $rows.Add((Get-MsgRow $State $L.W $Now))
  return @{ Rows = $rows; Fades = $null }
}

function Add-MenuCards {
  param($Rows, $Fades, $State, $L, [double]$Now)
  $h = $State.Hit
  $p = Get-TweenValue $State.SelTween $Now
  for ($i = $h.Top; $i -lt $h.Last; $i++) { Add-CardRows $Rows $Fades $State.Entries[$i] $i $L $p $Now }
  $m = [int][math]::Round(($p - $h.Top) * $L.Per)
  for ($j = 0; $j -lt $L.Per - 1; $j++) {
    $at = $h.Start + $m + $j
    if ($at -ge $h.Start -and $at -lt $Rows.Count) { Add-MarkSeg $Rows[$at] }
  }
}

function Get-MenuRows {
  param($State, $L, [double]$Now)
  $n = $State.Entries.Count
  $State.Top = Get-ScrollTop $State.Sel $State.Top $L.Visible $n
  $top = $State.Top
  $last = [math]::Min($n, $top + $L.Visible)
  if ($L.Mode -eq "simple") {
    $State.Hit = @{ Start = 1; Per = 1; Top = $top; Last = $last }
    return Get-SimpleRows $State $L $top $last $Now
  }
  $rows = New-Object 'System.Collections.Generic.List[object]'
  $fades = New-Object 'System.Collections.Generic.List[double]'
  $tip = ""
  if ($top -gt 0) { $tip = $script:UpArrow }
  Add-PlainRow $rows $fades (New-Row)
  Add-PlainRow $rows $fades (Get-MenuHeaderRow $State $L.W $Now)
  Add-PlainRow $rows $fades (Get-RuleRow $L.W $tip)
  Add-PlainRow $rows $fades (New-Row)
  $start = $rows.Count
  $State.Hit = @{ Start = $start; Per = $L.Per; Top = $top; Last = $last }
  Add-MenuCards $rows $fades $State $L $Now
  $tip = ""
  if ($last -lt $n) { $tip = $script:DownArrow }
  Add-PlainRow $rows $fades (Get-RuleRow $L.W $tip)
  foreach ($r in (Get-FooterRows $script:MenuFooter $L.W)) { Add-PlainRow $rows $fades $r }
  Add-PlainRow $rows $fades (Get-MsgRow $State $L.W $Now)
  return @{ Rows = $rows; Fades = $fades }
}

function Get-EntryAt {
  param($State, [int]$Y)
  $h = $State.Hit
  if ($null -eq $h -or $Y -lt $h.Start) { return -1 }
  $i = $h.Top + [math]::Floor(($Y - $h.Start) / $h.Per)
  if ($i -ge $h.Last) { return -1 }
  return [int]$i
}

function Get-MenuMouseAction {
  param($State, $Ev)
  $i = Get-EntryAt $State $Ev.Y
  if ($i -lt 0) { return @{ Name = "none" } }
  if ($Ev.Mouse -eq "double" -and $i -eq $State.Sel) { return @{ Name = "pick"; Index = $i } }
  return @{ Name = "select"; Index = $i }
}

function Show-Menu {
  param($State, [double]$Now)
  $L = Get-MenuLayout $script:UiCols $script:UiRows $State.Entries.Count
  $f = Get-MenuRows $State $L $Now
  Show-UiRows $f.Rows $Now $f.Fades
  $State.Dirty = $false
}

function Test-MenuAnimating {
  param($State, [double]$Now)
  if ((Test-UiAnimating $Now) -or $null -ne $script:InkTween -or (Test-TweenRunning $State.SelTween $Now)) { return $true }
  if ($null -ne $script:UiProgress -and ($script:UiProgress.Pct -lt 0 -or (Test-TweenRunning $script:UiProgress.Bar $Now))) { return $true }
  foreach ($e in $State.Entries) {
    if ($e.Pending -and -not $e.Seen -and $script:MotionOn) { return $true }
    if ((Test-TweenRunning $e.T5 $Now) -or (Test-TweenRunning $e.T7 $Now)) { return $true }
    if ($null -ne $e.In -and (Test-TweenRunning $e.In $Now)) { return $true }
  }
  return $false
}
