. (Join-Path $PSScriptRoot "claude-platform.ps1")
. (Join-Path $PSScriptRoot "claude-display.ps1")

function ConvertTo-ThemeName {
  param($Value, [switch]$French)
  $v = ("" + $Value).Trim().ToLower()
  if ($v -eq "light" -or ($French -and $v -eq "clair")) { return "light" }
  if ($v -eq "dark" -or ($French -and $v -eq "sombre")) { return "dark" }
  return $null
}

function ConvertFrom-AppsUseLightTheme {
  param($Value)
  if ($null -eq $Value) { return $null }
  if ([int]$Value -eq 1) { return "light" }
  return "dark"
}

function ConvertFrom-MacAppearance {
  param([string]$Output, [int]$Code)
  if ($Code -eq 0 -and $Output -match "Dark") { return "dark" }
  return "light"
}

function Get-KdeTheme {
  param([string]$Path)
  if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $null }
  $section = ""
  foreach ($l in Get-Content -LiteralPath $Path) {
    $t = $l.Trim()
    if ($t -match "^\[(.+)\]$") { $section = $Matches[1]; continue }
    if ($section -ne "Colors:Window" -or $t -notmatch "^BackgroundNormal\s*=\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)") { continue }
    $lum = (0.2126 * [int]$Matches[1] + 0.7152 * [int]$Matches[2] + 0.0722 * [int]$Matches[3]) / 255
    if ($lum -lt 0.5) { return "dark" }
    return "light"
  }
  return $null
}

function Get-LinuxTheme {
  param([string]$GnomeScheme, [string]$GtkTheme, [string]$KdeFile)
  if ($GnomeScheme -match "dark") { return "dark" }
  if ($GtkTheme -match ":dark") { return "dark" }
  return Get-KdeTheme $KdeFile
}

function Get-SystemTheme {
  param([string]$Os = $script:OsName, $Vars = $null)
  if ($Os -eq "Windows") {
    $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    try { $v = (Get-ItemProperty -LiteralPath $key -Name AppsUseLightTheme -ErrorAction Stop).AppsUseLightTheme } catch { $v = $null }
    return ConvertFrom-AppsUseLightTheme $v
  }
  if ($Os -eq "MacOS") {
    $r = Invoke-Captured "defaults" "read -g AppleInterfaceStyle" 3000
    if ($null -eq $r) { return $null }
    return ConvertFrom-MacAppearance $r.Out $r.Code
  }
  $scheme = ""
  if (Get-Command gsettings -CommandType Application -ErrorAction SilentlyContinue) {
    $r = Invoke-Captured "gsettings" "get org.gnome.desktop.interface color-scheme" 3000
    if ($null -ne $r -and $r.Code -eq 0) { $scheme = $r.Out }
  }
  $kde = Join-OsPath $Os @((Get-XdgDir "XDG_CONFIG_HOME" @(".config") $Vars), "kdeglobals")
  return Get-LinuxTheme $scheme (Read-EnvVar "GTK_THEME" $Vars) $kde
}

function Get-FixedTheme {
  param($Vars = $null)
  $t = ConvertTo-ThemeName (Read-EnvVar "STATUSLINE_BG" $Vars) -French
  if ($t) { return $t }
  $p = (Read-DisplayConfig $Vars).palette
  if ($p -ne "auto") { return $p }
  return $null
}

function Get-ThemeName {
  param([string]$Os = $script:OsName, $Vars = $null)
  $t = Get-FixedTheme $Vars
  if ($t) { return $t }
  $t = Get-SystemTheme $Os $Vars
  if ($t) { return $t }
  return "dark"
}

function Get-DisplayForced {
  param($Vars = $null)
  return @{ palette = ($null -ne (ConvertTo-ThemeName (Read-EnvVar "STATUSLINE_BG" $Vars) -French)); anim = (@("0", "1") -contains (Read-EnvVar "CLM_ANIM" $Vars)) }
}
