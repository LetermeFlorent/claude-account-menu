$script:BarFull = [string][char]0x2501
$script:BarEmpty = [string][char]0x2500
$script:Mark = [string][char]0x258C

function Get-BarCount {
  param([double]$P, [int]$C)
  if ($P -le 0) { return 0 }
  return [int][math]::Min($C, [math]::Ceiling($P * $C / 100))
}

function Add-SpanSeg {
  param($Segs, [string]$Glyph, [int]$N, $Rgb)
  if ($N -gt 0) { $Segs.Add(@(($Glyph * $N), $Rgb, $false)) }
}

function Add-BarSegs {
  param($Segs, [string]$Kind, [double]$P, $Base, [int]$C)
  $n = Get-BarCount $P $C
  $bands = [math]::Min(8, $n)
  $start = 0
  for ($b = 0; $b -lt $bands; $b++) {
    $end = [int][math]::Floor(($b + 1) * $n / $bands)
    $f = 1.0
    if ($bands -gt 1) { $f = 1 - $script:Grad[$Kind] * 0.345 * $b / ($bands - 1) }
    Add-SpanSeg $Segs $script:BarFull ($end - $start) @([int]($Base[0] * $f), [int]($Base[1] * $f), [int]($Base[2] * $f))
    $start = $end
  }
  Add-SpanSeg $Segs $script:BarEmpty ($C - $n) $script:Ink.Empty
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
  Add-SpanSeg $Segs $script:BarEmpty $a $script:Ink.Empty
  Add-SpanSeg $Segs $script:BarEmpty ($b - $a) $script:Ink.Dim
  Add-SpanSeg $Segs $script:BarEmpty ($C - $b) $script:Ink.Empty
}

function Add-ProgressSegs {
  param($Segs, [double]$Pct, [int]$C, [double]$Now)
  $a = 0
  $b = Get-BarCount $Pct $C
  if ($Pct -lt 0) {
    $w = [math]::Max(3, [int][math]::Floor($C / 4))
    $ph = ($Now % 1600) / 1600
    if (-not $script:MotionOn) { $ph = 0 }
    $a = [int][math]::Round((1 - [math]::Abs(2 * $ph - 1)) * ($C - $w))
    $b = $a + $w
  }
  Add-SpanSeg $Segs $script:BarEmpty $a $script:Ink.Empty
  Add-SpanSeg $Segs $script:BarFull ($b - $a) $script:Levels["7d"][0]
  Add-SpanSeg $Segs $script:BarEmpty ($C - $b) $script:Ink.Empty
}
