. Import-ClmModule claude-ui-color-depth
$script:BarFull = [string][char]0x2501
$script:BarEmpty = [string][char]0x254C
$script:BarCells = 16
$script:Mark = [string][char]0x25BA

function Get-BarCount {
  param([double]$P, [int]$C)
  if ($P -le 0) { return 0 }
  $n = [math]::Round($P * $C / 100, [MidpointRounding]::AwayFromZero)
  return [int][math]::Min($C, [math]::Max(1, $n))
}

function Get-BarHue {
  param([string]$Kind, [double]$P)
  $P = [math]::Round($P, 1, [MidpointRounding]::AwayFromZero)
  $lv = 0
  if ($P -ge 70) { $lv = 2 } elseif ($P -ge 30) { $lv = 1 }
  return ,$script:BarHues[$Kind][$lv]
}

function Add-SpanSeg {
  param($Segs, [string]$Glyph, [int]$N, $Rgb)
  if ($N -gt 0) { $Segs.Add(@(($Glyph * $N), $Rgb, $false)) }
}

function Add-BarSegs {
  param($Segs, [string]$Kind, [double]$P, $Base, [int]$C)
  $n = Get-BarCount $P $C
  Add-SpanSeg $Segs $script:BarFull $n $Base
  Add-SpanSeg $Segs $script:BarEmpty ($C - $n) $script:Ink.Cell
}

function Get-BarBase {
  param([string]$Kind, $Tween, [double]$Now)
  $to = Get-BarHue $Kind $Tween.To
  if (-not (Test-TweenRunning $Tween $Now)) { return ,$to }
  $from = Get-BarHue $Kind $Tween.From
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
  $ink = $script:BarHues["7d"][0]
  if ($Pct -ge 0) {
    $n = Get-BarCount $Pct $C
    Add-SpanSeg $Segs $script:BarFull $n $ink
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
