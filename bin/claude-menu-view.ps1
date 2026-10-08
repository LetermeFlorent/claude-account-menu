$script:Esc = [string][char]27
$script:Cell = [string][char]0x25A0
$script:HalfCell = [string][char]0x25AA
$script:Rule = [string][char]0x2500
$script:Pointer = [string][char]0x276F
$script:Cells = 8
$script:ViewWidth = 78
$script:Grad = @{ "5h" = 0.55; "7d" = 0.3 }
$script:Levels = @{
  "5h" = @(@(120, 110, 200), @(170, 90, 175), @(200, 60, 95))
  "7d" = @(@(83, 137, 119), @(185, 130, 68), @(185, 85, 85))
}
$script:Palettes = @{
  "light" = @{ Text = @(0, 0, 0); Dim = @(120, 112, 100); Empty = @(190, 180, 165); Alert = @(185, 85, 85) }
  "dark" = @{ Text = @(235, 235, 235); Dim = @(150, 150, 150); Empty = @(75, 75, 80); Alert = @(220, 100, 100) }
}
. (Join-Path $PSScriptRoot "claude-theme.ps1")
. (Join-Path $PSScriptRoot "claude-usage-pace.ps1")
. (Join-Path $PSScriptRoot "claude-menu-usage-line.ps1")
$script:Ink = $script:Palettes[(Get-ThemeName)]

$slConf = [IO.Path]::Combine((Get-HomeDir), ".claude", "statusline.json")
if (Test-Path -LiteralPath $slConf) {
  try {
    $sl = Get-Content -LiteralPath $slConf -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($sl.gradient.'5h' -ne $null) { $script:Grad["5h"] = [double]$sl.gradient.'5h' }
    if ($sl.gradient.'7d' -ne $null) { $script:Grad["7d"] = [double]$sl.gradient.'7d' }
  } catch {}
}

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
  if ($at -eq $null) { return "-" }
  $span = $at - [DateTimeOffset]::Now
  if ($span.TotalSeconds -le 0) { return "0m" }
  $h = [math]::Floor($span.TotalHours)
  if ($h -ge 24) { return "" + [math]::Floor($h / 24) + "j" + ($h % 24) + "h" }
  return "" + $h + "h" + ("{0:D2}" -f $span.Minutes) + "m"
}

function Get-Bar {
  param([string]$Kind, $Pct)
  $p = [int]$Pct
  $n = [math]::Min($script:Cells, [math]::Ceiling($p * $script:Cells / 100))
  $base = Get-LevelColor $Kind $p
  $s = ""
  for ($i = 0; $i -lt $script:Cells; $i++) {
    if ($i -ge $n) { $s += (Fg $script:Ink.Empty) + $script:Cell; continue }
    $f = 1.0
    if ($n -gt 1) { $f = 1 - $script:Grad[$Kind] * 0.345 * $i / ($n - 1) }
    $rgb = @([int]($base[0] * $f), [int]($base[1] * $f), [int]($base[2] * $f))
    $glyph = $script:Cell
    if ($i -eq $n - 1) { $glyph = $script:HalfCell }
    $s += (Fg $rgb) + $glyph
  }
  return $s
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

function Write-AccountCard {
  param($U, [int]$Num, [bool]$Sel)
  $mark = "   "
  if ($Sel) { $mark = " " + $script:Pointer + " " }
  $mailInk = $script:Ink.Dim
  if ($Sel) { $mailInk = $script:Ink.Text }
  $badge = ""
  if ($U.Error -eq $null -and [int]$U.Pct7 -ge 100) { $badge = "quota 7d atteint  " }
  elseif ($U.Error -eq $null -and [int]$U.Pct5 -ge 100) { $badge = "quota 5h atteint  " }
  $head = $mark + $Num + "  " + $U.Label + "  "
  $gap = [math]::Max(1, $script:ViewWidth - $head.Length - $U.Email.Length - $badge.Length - $U.Plan.Length)
  Write-Segs @(
    @($mark, $script:Levels["5h"][0], $true), @(("" + $Num + "  " + $U.Label + "  "), $script:Ink.Text, $Sel),
    @($U.Email, $mailInk, $Sel), @((" " * $gap), $script:Ink.Text, $false),
    @($badge, $script:Ink.Alert, $true), @($U.Plan, (Get-PlanColor $U.Plan), $true))
  if ($U.Error -ne $null) {
    Write-Segs @(, @(("       " + $U.Error), $script:Ink.Alert, $false))
  } else {
    Write-UsageLine $U
  }
  $note = ""
  if ($U.Age -ne $null -and $U.Age -ge 60) { $note = "       valeurs lues il y a " + (Format-Age $U.Age) }
  if ($U.Expired) { $note = "       fenetre passee depuis la derniere lecture il y a " + (Format-Age $U.Age) }
  Write-Segs @(, @($note, $script:Ink.Dim, $false))
}

function Show-AccountMenu {
  param($Usages, [int]$Idx, [int]$Top)
  [Console]::SetCursorPosition(0, $Top)
  $rule = @(, @(("  " + ($script:Rule * ($script:ViewWidth - 4))), $script:Ink.Empty, $false))
  Write-Segs @(, @("", $script:Ink.Text, $false))
  Write-Segs @(@("  Comptes Claude Code".PadRight($script:ViewWidth - 5), $script:Ink.Text, $true), @((Get-Date -Format "HH:mm"), $script:Ink.Dim, $false))
  Write-Segs $rule
  for ($i = 0; $i -lt $Usages.Count; $i++) { Write-AccountCard $Usages[$i] ($i + 1) ($i -eq $Idx) }
  Write-Segs $rule
  Write-Segs @(, @("  Entree lancer  a ajouter  x retirer  s sauvegarder  r restaurer  q quitter", $script:Ink.Dim, $false))
}
