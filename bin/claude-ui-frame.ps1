$script:FrameLines = $null
$script:LastRows = $null
$script:LastFades = $null
$script:ScreenFade = $null
$script:FadeArmed = $false
$script:UiCols = 80
$script:UiRows = 24
$script:UiClip = 79

function Reset-Frame {
  $script:FrameLines = $null
}

function ConvertTo-LineText {
  param([object[]]$Segs, [int]$Max, [double]$Fade = 1, $Bg = $null)
  $e = $script:Esc
  $sb = New-Object Text.StringBuilder 256
  $left = $Max
  if ($Fade -lt 0) { $Fade = 0 }
  foreach ($s in $Segs) {
    if ($left -le 0) { break }
    $t = [string]$s[0]
    if ($t.Length -eq 0) { continue }
    if ($t.Length -gt $left) { $t = $t.Substring(0, $left) }
    $c = $s[1]
    $r = [int]$c[0]; $g = [int]$c[1]; $b = [int]$c[2]
    if ($Fade -lt 1) {
      $r = [int]($Bg[0] + ($r - $Bg[0]) * $Fade)
      $g = [int]($Bg[1] + ($g - $Bg[1]) * $Fade)
      $b = [int]($Bg[2] + ($b - $Bg[2]) * $Fade)
    }
    [void]$sb.Append($e).Append("[0")
    if ($s[2]) { [void]$sb.Append(";1") }
    [void]$sb.Append(";38;2;").Append($r).Append(";").Append($g).Append(";").Append($b).Append("m").Append($t)
    $left -= $t.Length
  }
  [void]$sb.Append($e).Append("[0m")
  return $sb.ToString()
}

function Get-FrameUpdate {
  param([string[]]$Lines, [string[]]$Prev)
  $e = $script:Esc
  $sb = New-Object Text.StringBuilder 4096
  $old = 0
  if ($null -ne $Prev) { $old = $Prev.Count }
  for ($i = 0; $i -lt $Lines.Count; $i++) {
    if ($i -lt $old -and $Prev[$i] -ceq $Lines[$i]) { continue }
    [void]$sb.Append($e).Append("[").Append($i + 1).Append(";1H").Append($Lines[$i]).Append($e).Append("[K")
  }
  for ($i = $Lines.Count; $i -lt $old; $i++) {
    [void]$sb.Append($e).Append("[").Append($i + 1).Append(";1H").Append($e).Append("[2K")
  }
  return $sb.ToString()
}

function Write-Frame {
  param($Rows, [int]$Max, $Fades = $null)
  $n = [math]::Min($Rows.Count, $script:UiRows)
  $lines = [string[]]::new($n)
  $bg = $script:Ink.Bg
  for ($i = 0; $i -lt $n; $i++) {
    $f = 1.0
    if ($null -ne $Fades) { $f = $Fades[$i] }
    $lines[$i] = ConvertTo-LineText $Rows[$i] $Max $f $bg
  }
  $u = Get-FrameUpdate $lines $script:FrameLines
  $script:FrameLines = $lines
  if ($u.Length -gt 0) { Write-Ui ($script:Esc + "[?2026h" + $u + $script:Esc + "[?2026l") }
}

function Show-UiRows {
  param($Rows, [double]$Now, $RowFades = $null)
  if ($script:FadeArmed) { $script:ScreenFade = New-Tween 0 1 150 $Now; $script:FadeArmed = $false }
  $g = 1.0
  if ($null -ne $script:ScreenFade) { $g = Get-TweenValue $script:ScreenFade $Now }
  $fades = $null
  if ($g -lt 1 -or $null -ne $RowFades) {
    $fades = [double[]]::new($Rows.Count)
    for ($i = 0; $i -lt $Rows.Count; $i++) {
      $f = $g
      if ($null -ne $RowFades -and $i -lt $RowFades.Count) { $f = $f * $RowFades[$i] }
      $fades[$i] = $f
    }
  }
  $script:LastRows = $Rows
  $script:LastFades = $RowFades
  Write-Frame $Rows $script:UiClip $fades
}

function Hide-Screen {
  $rows = $script:LastRows
  if ($null -ne $rows -and $script:MotionOn) {
    $t = New-Tween 1 0 120 (Get-NowMs)
    $fades = [double[]]::new($rows.Count)
    while ($true) {
      $now = Get-NowMs
      $f = Get-TweenValue $t $now
      for ($i = 0; $i -lt $fades.Count; $i++) {
        $fades[$i] = $f
        if ($null -ne $script:LastFades -and $i -lt $script:LastFades.Count) { $fades[$i] = $f * $script:LastFades[$i] }
      }
      Write-Frame $rows $script:UiClip $fades
      if (-not (Test-TweenRunning $t $now)) { break }
      Start-Sleep -Milliseconds 16
    }
  }
  Write-Ui ($script:Esc + "[2J")
  Reset-Frame
  $script:LastRows = $null
  $script:FadeArmed = $true
}

function Test-UiAnimating {
  param([double]$Now)
  return ($null -ne $script:ScreenFade -and (Test-TweenRunning $script:ScreenFade $Now))
}
