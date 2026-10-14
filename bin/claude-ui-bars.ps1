$script:BarFull = [string][char]0x25A0
$script:BarEmpty = [string][char]0x25A0
$script:BarHalf = [string][char]0x25AA
$script:Mark = [string][char]0x258C

function Get-BarCount {
  param([double]$P, [int]$C)
  if ($P -le 0) { return 0 }
  $units = [math]::Round($P * 2 * $C / 100, [MidpointRounding]::AwayFromZero)
  return [int][math]::Min($C, [math]::Max(1, [math]::Ceiling($units / 2)))
}

function Test-InkLight {
  $b = $script:Ink.Bg
  return (0.2126 * $b[0] + 0.7152 * $b[1] + 0.0722 * $b[2]) -gt 128
}

function Get-LerpRgb {
  param($From, $To, [double]$T)
  $c = @(0, 0, 0)
  for ($k = 0; $k -lt 3; $k++) { $c[$k] = [int][math]::Round($From[$k] + ($To[$k] - $From[$k]) * $T, [MidpointRounding]::AwayFromZero) }
  return ,$c
}

function Get-BarEnd {
  param($Base, [double]$G)
  $light = Test-InkLight
  $target = @(0, 0, 0)
  for ($k = 0; $k -lt 3; $k++) {
    $v = $Base[$k] + (255 - $Base[$k]) * 0.3
    if ($light) { $v = $Base[$k] * 0.65 }
    $target[$k] = [math]::Round($v, [MidpointRounding]::AwayFromZero)
  }
  $end = @(0, 0, 0)
  for ($k = 0; $k -lt 3; $k++) { $end[$k] = $Base[$k] + ($target[$k] - $Base[$k]) * $G }
  return ,$end
}

function Add-SpanSeg {
  param($Segs, [string]$Glyph, [int]$N, $Rgb)
  if ($N -gt 0) { $Segs.Add(@(($Glyph * $N), $Rgb, $false)) }
}

function Add-FilledSegs {
  param($Segs, [int]$N, $From, $To)
  for ($i = 0; $i -lt $N; $i++) {
    $t = 0.0
    if ($N -gt 1) { $t = $i / ($N - 1) }
    $glyph = $script:BarFull
    if ($i -eq $N - 1) { $glyph = $script:BarHalf }
    $Segs.Add(@($glyph, (Get-LerpRgb $From $To $t), $false))
  }
}

function Add-BarSegs {
  param($Segs, [string]$Kind, [double]$P, $Base, [int]$C)
  $n = Get-BarCount $P $C
  Add-FilledSegs $Segs $n $Base (Get-BarEnd $Base $script:Grad[$Kind])
  Add-SpanSeg $Segs $script:BarEmpty ($C - $n) $script:Ink.Cell
}

function Get-BarBase {
  param([string]$Kind, $Tween, [double]$Now)
  $to = Get-LevelColor $Kind ([int]$Tween.To)
  if (-not (Test-TweenRunning $Tween $Now)) { return ,$to }
  $from = Get-LevelColor $Kind ([int]$Tween.From)
  return ,(Get-MixedRgb $from $to (Get-EaseOut (($Now - $Tween.Start) / $Tween.Ms)))
}

function Add-ShimmerSegs {
  param($Segs, [int]$C, [double]$Now)
  $w = [math]::Max(2, [int][math]::Floor($C / 5))
  $pos = -$w
  if ($script:MotionOn) { $pos = [int][math]::Floor(($Now % 1200) / 1200 * ($C + $w)) - $w }
  $a = [math]::Max(0, [math]::Min($C, $pos))
  $b = [math]::Max(0, [math]::Min($C, $pos + $w))
  Add-SpanSeg $Segs $script:BarEmpty $a $script:Ink.Cell
  Add-SpanSeg $Segs $script:BarEmpty ($b - $a) $script:Ink.Dim
  Add-SpanSeg $Segs $script:BarEmpty ($C - $b) $script:Ink.Cell
}

function Add-ProgressSegs {
  param($Segs, [double]$Pct, [int]$C, [double]$Now)
  $ink = $script:Levels["7d"][0]
  if ($Pct -ge 0) {
    $n = Get-BarCount $Pct $C
    Add-FilledSegs $Segs $n $ink $ink
    Add-SpanSeg $Segs $script:BarEmpty ($C - $n) $script:Ink.Cell
    return
  }
  $w = [math]::Max(3, [int][math]::Floor($C / 4))
  $ph = ($Now % 1600) / 1600
  if (-not $script:MotionOn) { $ph = 0 }
  $a = [int][math]::Round((1 - [math]::Abs(2 * $ph - 1)) * ($C - $w))
  Add-SpanSeg $Segs $script:BarEmpty $a $script:Ink.Cell
  Add-SpanSeg $Segs $script:BarFull $w $ink
  Add-SpanSeg $Segs $script:BarEmpty ($C - $a - $w) $script:Ink.Cell
}
