. Import-ClmModule claude-text, claude-ui-width
function Get-MsgRow {
  param($State, [int]$W, [double]$Now)
  if ($null -ne $script:UiProgress) { return ,(Get-ProgressRow $W $Now) }
  $r = New-Row
  $r.Add(@($State.Msg[0], $State.Msg[1], $true))
  return ,$r
}

function Get-MenuHeaderRow {
  param($State, [int]$W)
  $r = Get-HeaderRow (Get-ClmText "menu.screen.title") $W
  $clock = @(("  " + (Get-Date -Format "HH:mm")), $script:Ink.Dim, $false)
  $room = $W - 4 - (Get-DisplayWidth $clock[0]) - (Get-SegsLength $r)
  $tag = @(("  " + $State.Version), $script:Ink.Dim, $false)
  if (-not $State.Version) { $tag[0] = "" }
  $drive = @()
  $dt = Get-DriveTag $script:DriveJob
  if ($dt[0]) { $drive = @(@("  ", $script:Ink.Dim, $false), @($dt[0], $dt[1], $false, "y")) }
  $button = @()
  if (Test-ClmUpdateReady) { $button = @(@("  ", $script:Ink.Dim, $false), @(("[" + (Get-ClmText "menu.screen.updateAvailable") + "]"), $script:Levels["7d"][1], $true, "u")) }
  $len = Get-SegsLength $button
  $tagWidth = Get-DisplayWidth $tag[0]
  $tlen = 0
  if ($tag[0] -and $room -ge $tagWidth + $len) { $r.Add($tag); $tlen = $tagWidth }
  $dlen = Get-SegsLength $drive
  if ($dlen -gt 0 -and ($tlen -gt 0 -or -not $tag[0]) -and $room -ge $tlen + $dlen + $len) { foreach ($s in $drive) { $r.Add($s) } }
  if ($len -gt 0 -and $room -ge $len) { foreach ($s in $button) { $r.Add($s) } }
  Add-RightSegs $r ($W - 2) @(, $clock)
  return ,$r
}

function Get-SimpleRows {
  param($State, $L, [int]$Top, [int]$Last, [double]$Now)
  $rows = New-Object 'System.Collections.Generic.List[object]'
  $rows.Add((Get-HeaderRow (Get-ClmText "menu.screen.title") $L.W))
  Add-StartupTextRows $rows $script:Startup $Now
  $State.Hit.Start = $rows.Count
  for ($i = $Top; $i -lt $Last; $i++) {
    $e = $State.Entries[$i]
    $u = $e.U
    $r = New-Row
    $mark = "   "
    if ($i -eq $State.Sel) { $mark = " " + $script:Mark + " " }
    $r.Add(@($mark, $script:Levels["5h"][0], $false))
    $r.Add(@(("" + ($i + 1) + "  " + $u.Label + "  "), $script:Ink.Text, ($i -eq $State.Sel)))
    if ($null -ne $u.Error) { $r.Add(@(("" + $u.Error), $script:Ink.Alert, $false)) }
    elseif ($e.Pending -and -not $e.Seen) { $r.Add(@((Get-ClmText "menu.screen.reading"), $script:Ink.Dim, $false)) }
    else { $r.Add(@(("5h " + [int]$u.Pct5 + "%  7d " + [int]$u.Pct7 + "%"), $script:Ink.Dim, $false)) }
    $rows.Add($r)
  }
  $rows.Add((Get-MsgRow $State $L.W $Now))
  return @{ Rows = $rows; Fades = $null }
}

function Add-MenuCards {
  param($Rows, $Fades, $State, $L, [double]$Now)
  $h = $State.Hit
  if ($h.Last -le $h.Top) { return }
  $p = Get-TweenValue $State.SelTween $Now
  for ($i = $h.Top; $i -lt $h.Last; $i++) { Add-CardRows @{ Rows = $Rows; Fades = $Fades; Entry = $State.Entries[$i]; Index = $i; Layout = $L; Position = $p; Now = $Now } }
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
  if (Test-AccountsWaiting $script:Startup) { $last = $top }
  if ($L.Mode -eq "simple") {
    $State.Hit = @{ Start = 1; Per = 1; Top = $top; Last = $last }
    return Get-SimpleRows $State $L $top $last $Now
  }
  $rows = New-Object 'System.Collections.Generic.List[object]'
  $fades = New-Object 'System.Collections.Generic.List[double]'
  $tip = ""
  if ($top -gt 0) { $tip = $script:UpArrow }
  Add-PlainRow $rows $fades (New-Row)
  Add-PlainRow $rows $fades (Get-MenuHeaderRow $State $L.W)
  Add-PlainRow $rows $fades (Get-RuleRow $L.W $tip)
  Add-PlainRow $rows $fades (New-Row)
  Add-StartupRows $rows $fades $script:Startup $L $Now
  $start = $rows.Count
  $State.Hit = @{ Start = $start; Per = $L.Per; Top = $top; Last = $last }
  Add-MenuCards $rows $fades $State $L $Now
  $tip = ""
  if ($last -lt $n -and $last -gt $top) { $tip = $script:DownArrow }
  Add-PlainRow $rows $fades (Get-RuleRow $L.W $tip)
  foreach ($r in (Get-FooterRows (Get-MenuFooter) $L.W $script:MenuFooterAccent)) { Add-PlainRow $rows $fades $r }
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
  if ($Ev.Mouse -eq "click") { $State.Armed = $i }
  elseif ($i -eq $State.Sel -and $State.Armed -eq $i) { return @{ Name = "pick"; Index = $i } }
  return @{ Name = "select"; Index = $i }
}

function Show-Menu {
  param($State, [double]$Now)
  $L = Get-MenuLayout $script:UiCols $script:UiRows $State.Entries.Count (Get-StartupRowCount $script:Startup)
  $f = Get-MenuRows $State $L $Now
  if ($L.Mode -ne "simple") { $f = @{ Rows = (Get-FramedRows $f.Rows $f.Fades $L.W); Fades = $null } }
  Show-UiRows $f.Rows $Now $f.Fades
  $State.Dirty = $false
}

function Open-MenuFrame {
  Show-Menu $script:MenuState (Get-NowMs)
  Clear-UiInput
  $script:MenuState.Opened = $true
}

function Test-MenuAnimating {
  param($State, [double]$Now)
  if ((Test-UiAnimating $Now) -or $null -ne $script:InkTween -or (Test-TweenRunning $State.SelTween $Now)) { return $true }
  if ($null -ne $script:UiProgress -and ($script:UiProgress.Pct -lt 0 -or (Test-TweenRunning $script:UiProgress.Bar $Now))) { return $true }
  if (Test-StartupAnimating $script:Startup $Now) { return $true }
  foreach ($e in $State.Entries) {
    if ($e.Pending -and -not $e.Seen -and $script:MotionOn) { return $true }
    if ((Test-TweenRunning $e.T5 $Now) -or (Test-TweenRunning $e.T7 $Now)) { return $true }
    if ($null -ne $e.In -and (Test-TweenRunning $e.In $Now)) { return $true }
  }
  return $false
}
