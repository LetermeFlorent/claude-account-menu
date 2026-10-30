. Import-ClmModule claude-platform, claude-display
$script:ThemePersonalizeKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
$script:ThemeGtkDark = New-Object regex '(?i)[-:]dark$'

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

function Test-GtkDarkName {
  param([string]$Name)
  return $script:ThemeGtkDark.IsMatch(("" + $Name).Trim().Trim("'"))
}

function Get-LinuxTheme {
  param([string]$GnomeScheme, [string]$GtkTheme, [string]$KdeFile)
  if ($GnomeScheme -match "dark") { return "dark" }
  if (Test-GtkDarkName $GtkTheme) { return "dark" }
  return Get-KdeTheme $KdeFile
}

function Read-WindowsLightTheme {
  try { return (Get-ItemProperty -LiteralPath $script:ThemePersonalizeKey -Name AppsUseLightTheme -ErrorAction Stop).AppsUseLightTheme } catch { return $null }
}

function Read-MacAppearance {
  return Invoke-Captured "defaults" "read -g AppleInterfaceStyle" 3000
}

function Read-GnomeSetting {
  param([string]$Name)
  if (-not (Get-Command gsettings -CommandType Application -ErrorAction SilentlyContinue)) { return "" }
  $r = Invoke-Captured "gsettings" ("get org.gnome.desktop.interface " + $Name) 3000
  if ($null -eq $r -or $r.Code -ne 0) { return "" }
  return [string]$r.Out
}

function Read-LinuxTheme {
  param([string]$Os, $Vars)
  $scheme = Read-GnomeSetting "color-scheme"
  if ($scheme -match "dark") { return "dark" }
  $gtk = Read-EnvVar "GTK_THEME" $Vars
  if (-not (Test-GtkDarkName $gtk)) { $gtk = Read-GnomeSetting "gtk-theme" }
  $kde = Join-OsPath $Os @((Get-XdgDir "XDG_CONFIG_HOME" @(".config") $Vars), "kdeglobals")
  return Get-LinuxTheme $scheme $gtk $kde
}

function Read-OsTheme {
  param([string]$Os, $Vars)
  if ($Os -eq "Windows") { return ConvertFrom-AppsUseLightTheme (Read-WindowsLightTheme) }
  if ($Os -ne "MacOS") { return Read-LinuxTheme $Os $Vars }
  $r = Read-MacAppearance
  if ($null -eq $r) { return $null }
  return ConvertFrom-MacAppearance $r.Out $r.Code
}

function Get-SystemTheme {
  param([string]$Os = $script:OsName, $Vars = $null)
  try { return [string](Read-OsTheme $Os $Vars) } catch { return "" }
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
