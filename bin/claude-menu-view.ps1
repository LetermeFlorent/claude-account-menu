$script:Esc = [string][char]27
$script:Rule = [string][char]0x2500
$script:ViewWidth = 78
$script:Grad = @{ "5h" = 0.55; "7d" = 0.3 }
$script:Levels = @{
  "5h" = @(@(120, 110, 200), @(170, 90, 175), @(200, 60, 95))
  "7d" = @(@(83, 137, 119), @(185, 130, 68), @(185, 85, 85))
}
$script:Palettes = @{
  "light" = @{ Text = @(0, 0, 0); Dim = @(120, 112, 100); Empty = @(190, 180, 165); Cell = @(190, 180, 165); Alert = @(185, 85, 85); Bg = @(250, 250, 250) }
  "dark" = @{ Text = @(232, 234, 237); Dim = @(150, 150, 150); Empty = @(75, 75, 80); Cell = @(226, 229, 234); Alert = @(220, 100, 100); Bg = @(12, 12, 12) }
}
. (Join-Path $PSScriptRoot "claude-theme.ps1")
. (Join-Path $PSScriptRoot "claude-usage-pace.ps1")
. (Join-Path $PSScriptRoot "claude-menu-usage-line.ps1")
. (Join-Path $PSScriptRoot "claude-ui-motion.ps1")
. (Join-Path $PSScriptRoot "claude-ui-frame.ps1")
. (Join-Path $PSScriptRoot "claude-ui-theme.ps1")
. (Join-Path $PSScriptRoot "claude-ui-term.ps1")
. (Join-Path $PSScriptRoot "claude-menu-layout.ps1")
. (Join-Path $PSScriptRoot "claude-menu-keys.ps1")
. (Join-Path $PSScriptRoot "claude-ui-loader.ps1")
. (Join-Path $PSScriptRoot "claude-ui-bars.ps1")
. (Join-Path $PSScriptRoot "claude-ui-chrome.ps1")
. (Join-Path $PSScriptRoot "claude-menu-card.ps1")
. (Join-Path $PSScriptRoot "claude-menu-state.ps1")
. (Join-Path $PSScriptRoot "claude-menu-timer.ps1")
. (Join-Path $PSScriptRoot "claude-menu-clm-check.ps1")
. (Join-Path $PSScriptRoot "claude-drive-job.ps1")
. (Join-Path $PSScriptRoot "claude-menu-startup-view.ps1")
. (Join-Path $PSScriptRoot "claude-menu-screen.ps1")
. (Join-Path $PSScriptRoot "claude-ui-progress.ps1")
. (Join-Path $PSScriptRoot "claude-ui-mouse.ps1")
. (Join-Path $PSScriptRoot "claude-ui-page.ps1")
$script:Ink = $script:Palettes[(Get-ThemeName)]

function Fg {
  param($Rgb, [bool]$Bold = $false)
  $b = ""
  if ($Bold) { $b = $script:Esc + "[1m" }
  return $script:Esc + "[0m" + $b + $script:Esc + "[38;2;" + $Rgb[0] + ";" + $Rgb[1] + ";" + $Rgb[2] + "m"
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
  foreach ($sg in $Segs) { $line += (Fg $sg[1] $sg[2]) + $sg[0]; $len += $sg[0].Length }
  $pad = [math]::Max(0, $script:ViewWidth - $len)
  Write-Host ($line + (" " * $pad) + $script:Esc + "[0m")
}

function Get-PlanColor {
  param([string]$Plan)
  if ($Plan -match "20x") { return $script:Levels["5h"][1] }
  if ($Plan -match "5x") { return $script:Levels["5h"][0] }
  return $script:Levels["7d"][0]
}
