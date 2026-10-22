$script:StartupLabelWidth = 13
$script:StartupCellsMax = 20

function Get-StartupRowCount {
  param($Su)
  if ($null -eq $Su -or $Su.Hidden) { return 0 }
  $n = (Get-ShownSteps $Su).Count
  if ($n -eq 0) { return 0 }
  return $n + 1
}

function Test-AccountsWaiting {
  param($Su)
  return (Get-StartupRowCount $Su) -gt 0 -and (Test-StartupBlocking $Su)
}

function Get-StartupTextInk {
  param($Step)
  if ($Step.Kind -eq "failed") { return $script:Ink.Alert }
  if ($Step.Kind -eq "updated") { return $script:Levels["7d"][0] }
  return $script:Ink.Dim
}

function Get-StartupPct {
  param($Step, [double]$Now)
  if ($Step.State -ne "run" -or $Step.Pct -lt 0) { return "" }
  return "" + [int][math]::Round((Get-TweenValue $Step.Bar $Now)) + "%"
}

function Add-StartupBarSegs {
  param($Row, $Step, [int]$C, [double]$Now)
  if ($Step.State -eq "wait") { Add-SpanSeg $Row $script:BarEmpty $C $script:Ink.Cell; return }
  if ($Step.State -eq "run" -and $Step.Pct -lt 0) { Add-ShimmerSegs $Row $C $Now; return }
  $base = $script:Levels["7d"][0]
  if ($Step.Kind -eq "failed") { $base = $script:Ink.Alert }
  Add-BarSegs $Row "7d" (Get-TweenValue $Step.Bar $Now) $base $C
}

function Get-StartupRow {
  param($Step, $L, [double]$Now)
  $r = New-Row
  $r.Add(@(("  " + $Step.Label.PadRight($script:StartupLabelWidth)), $script:Ink.Text, $true))
  Add-StartupBarSegs $r $Step ([math]::Min($script:StartupCellsMax, $L.Cells)) $Now
  $pct = Get-StartupPct $Step $Now
  if ($pct) { $r.Add(@(("  " + $pct.PadLeft(4)), $script:Ink.Text, $true)) }
  $room = $L.W - 4 - (Get-SegsLength $r)
  if ($Step.Text -and $room -ge 4) { $r.Add(@(("  " + (Limit-Text $Step.Text $room)), (Get-StartupTextInk $Step), $false)) }
  return ,$r
}

function Add-StartupRows {
  param($Rows, $Fades, $Su, $L, [double]$Now)
  if ((Get-StartupRowCount $Su) -eq 0) { return }
  foreach ($s in (Get-ShownSteps $Su)) {
    $f = 1.0
    if ($null -ne $s.Fade) { $f = $f * (Get-TweenValue $s.Fade $Now) }
    $Rows.Add((Get-StartupRow $s $L $Now))
    $Fades.Add($f)
  }
  Add-PlainRow $Rows $Fades (New-Row)
}

function Add-StartupTextRows {
  param($Rows, $Su, [double]$Now)
  if ((Get-StartupRowCount $Su) -eq 0) { return }
  foreach ($s in (Get-ShownSteps $Su)) {
    $t = Get-StartupPct $s $Now
    if ($t) { $t += "  " }
    $r = New-Row
    $r.Add(@(("  " + $s.Label + "  "), $script:Ink.Text, $true))
    $r.Add(@(($t + $s.Text), (Get-StartupTextInk $s), $false))
    $Rows.Add($r)
  }
}

function Test-StartupAnimating {
  param($Su, [double]$Now)
  if ((Get-StartupRowCount $Su) -eq 0) { return $false }
  foreach ($s in (Get-ShownSteps $Su)) {
    if ($null -ne $s.Fade -and (Test-TweenRunning $s.Fade $Now)) { return $true }
    if ($s.State -eq "run" -and $s.Pct -lt 0 -and $script:MotionOn) { return $true }
    if (Test-TweenRunning $s.Bar $Now) { return $true }
  }
  return $false
}
