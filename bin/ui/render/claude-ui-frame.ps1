. Import-ClmModule claude-ui-width, claude-ui-color-depth
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

function Get-FadedRgb {
  param($Rgb, [double]$Fade, $Bg)
  if ($Fade -lt 0) { $Fade = 0 }
  return @([int]($Bg[0] + ($Rgb[0] - $Bg[0]) * $Fade), [int]($Bg[1] + ($Rgb[1] - $Bg[1]) * $Fade), [int]($Bg[2] + ($Rgb[2] - $Bg[2]) * $Fade))
}

function ConvertTo-LineText {
  param([object[]]$Segs, [int]$Max, [double]$Fade = 1, $Bg = $null)
  $e = $script:Esc
  $sb = New-Object Text.StringBuilder 256
  $left = $Max
  $rgb = $script:UiColorDepth -eq "truecolor"
  if ($Fade -lt 0) { $Fade = 0 }
  if ($script:UiColorDepth -eq "16" -or $script:UiColorDepth -eq "none") { $Fade = 1 }
  foreach ($s in $Segs) {
    if ($left -le 0) { break }
    $t = [string]$s[0]
    if ($t.Length -eq 0) { continue }
    $w = Get-DisplayWidth $t
    if ($w -gt $left) { $t = Limit-DisplayText $t $left; $t += " " * ($left - (Get-DisplayWidth $t)); $w = $left }
    $c = $s[1]
    if ($Fade -lt 1) { $c = Get-FadedRgb $c $Fade $Bg }
    [void]$sb.Append($e).Append("[0")
    if ($s[2]) { [void]$sb.Append(";1") }
    if ($rgb) { [void]$sb.Append(";38;2;").Append([int]$c[0]).Append(";").Append([int]$c[1]).Append(";").Append([int]$c[2]) }
    else { [void]$sb.Append((Get-ColorSgr $c)) }
    [void]$sb.Append("m").Append($t)
    $left -= $w
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
