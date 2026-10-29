function Get-RgbSign {
  param([object[]]$Colors)
  return (@(foreach ($c in $Colors) { $c -join "," }) -join ";")
}

function Get-ThemeSign {
  $ink = $script:Ink
  $levels = @($script:Levels["5h"]) + @($script:Levels["7d"])
  $inks = Get-RgbSign @($ink.Text, $ink.Dim, $ink.Empty, $ink.Cell, $ink.Alert, $ink.Bg)
  return $inks + "|" + (Get-RgbSign $levels) + "|" + $script:Grad["5h"] + "," + $script:Grad["7d"] + "|" + $script:MotionOn
}

function Get-PaceSign {
  param($Pace)
  if ($null -eq $Pace) { return "" }
  return $Pace.Text + "/" + $Pace.Tone
}

function Get-CardSign {
  param($E, [int]$I, $L, [double]$W)
  $u = $E.U
  $v = $E.View
  $timer = ""
  if ($E.Timer) { $timer = $E.Timer[0] + "/" + ($E.Timer[1] -join ",") }
  $parts = @($I, $L.Mode, $L.W, $L.Cells, $W, $u.Label, $u.Email, $u.Plan, ($null -eq $u.Error), $u.Error, $u.Pct5, $u.Pct7, (Get-AccountAway $u.Acc), $timer,
    $v.Badge, $v.Note, $v.Left5, $v.Left7, (Get-PaceSign $v.Pace5), (Get-PaceSign $v.Pace7), $E.Pending, $E.Seen, $E.T5.To, $E.T7.To, (Get-ThemeSign))
  return ($parts -join [char]1)
}

function Test-CardMoving {
  param($E, [double]$Now)
  if ($E.Pending -and -not $E.Seen -and $script:MotionOn) { return $true }
  return (Test-TweenRunning $E.T5 $Now) -or (Test-TweenRunning $E.T7 $Now)
}

function Copy-CardRows {
  param($Rows)
  $out = New-Object 'System.Collections.Generic.List[object]'
  foreach ($r in $Rows) {
    $c = New-Row
    $c.AddRange($r)
    $out.Add($c)
  }
  return ,$out
}

function Get-CardRows {
  param($E, [int]$I, $L, [double]$W, [double]$Now)
  $moving = Test-CardMoving $E $Now
  $sign = $null
  if (-not $moving) {
    $sign = Get-CardSign $E $I $L $W
    if ($null -ne $E.CardRows -and $E.CardSign -ceq $sign) { return ,(Copy-CardRows $E.CardRows) }
  }
  $out = Get-CardHead $E $I $L $W
  $out.AddRange((Get-CardBody $E $L $Now))
  $out.Add((New-Row))
  $E.CardSign = $sign
  $E.CardRows = $null
  if (-not $moving) { $E.CardRows = Copy-CardRows $out }
  return ,$out
}
