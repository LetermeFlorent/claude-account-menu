$script:Esc = [string][char]27
$script:Rule = [string][char]0x2500
$script:ViewWidth = 78
$script:Grad = @{ "5h" = 0.55; "7d" = 0.3 }
. Import-ClmModule claude-ui-palette, claude-ui-width, claude-ui-color-depth, claude-ui-console-theme, claude-theme, claude-usage-pace, claude-menu-usage-line, claude-ui-motion, claude-ui-frame,
  claude-ui-theme, claude-ui-term, claude-menu-layout, claude-menu-keys, claude-ui-loader, claude-ui-bars,
  claude-ui-chrome, claude-menu-card, claude-menu-state, claude-menu-timer, claude-menu-clm-check, claude-drive-job,
  claude-menu-startup-view, claude-menu-screen, claude-ui-progress, claude-ui-mouse, claude-ui-page
Use-Palette (Get-ConsoleTheme)

function Fg {
  param($Rgb, [bool]$Bold = $false)
  $b = ""
  if ($Bold) { $b = ";1" }
  return $script:Esc + "[0" + $b + (Get-ColorSgr $Rgb) + "m"
}

function Get-LevelColor {
  param([string]$Kind, [int]$P)
  $lv = 0
  if ($P -ge 70) { $lv = 2 } elseif ($P -ge 30) { $lv = 1 }
  return $script:Levels[$Kind][$lv]
}

function Format-Left {
  param($Iso)
  $at = ConvertTo-DateOffset $Iso
  if ($null -eq $at) { return "-" }
  $span = $at - [DateTimeOffset]::Now
  if ($span.TotalSeconds -le 0) { return "0m" }
  $h = [int][math]::Floor($span.TotalHours)
  if ($h -lt 1) { return "" + $span.Minutes + "m" }
  if ($h -ge 24) { return "" + [math]::Floor($h / 24) + "d" + ("{0:D2}" -f ($h % 24)) + "h" }
  return "" + $h + "h" + ("{0:D2}" -f $span.Minutes) + "m"
}

function Write-Segs {
  param([object[]]$Segs)
  $line = ""; $len = 0
  foreach ($sg in $Segs) { $line += (Fg $sg[1] $sg[2]) + $sg[0]; $len += Get-DisplayWidth $sg[0] }
  $pad = [math]::Max(0, $script:ViewWidth - $len)
  Write-Host ($line + (" " * $pad) + $script:Esc + "[0m")
}

function Get-PlanColor {
  param([string]$Plan)
  if ($Plan -match "20x") { return $script:Levels["5h"][1] }
  if ($Plan -match "5x") { return $script:Levels["5h"][0] }
  return $script:Levels["7d"][0]
}
