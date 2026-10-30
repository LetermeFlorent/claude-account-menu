. Import-ClmModule claude-ui-motion, claude-lang, claude-theme, claude-color, claude-display, claude-web-page
$script:WebLookMs = 10000
$script:WebLookCache = $null
$script:WebThemes = @("light", "dark")

function Get-WebSystemLook {
  param([double]$Now = (Get-NowMs))
  $c = $script:WebLookCache
  if ($null -ne $c -and $Now -lt $c.Until) { return $c }
  $c = @{ Until = $Now + $script:WebLookMs; Theme = (Get-SystemTheme); Accent = (Read-WindowsAccent) }
  $script:WebLookCache = $c
  return $c
}

function Clear-WebSystemLook {
  $script:WebLookCache = $null
}

function ConvertTo-WebTheme {
  param([string]$Pref, [string]$Found)
  if ($script:WebThemes -ccontains $Pref) { return $Pref }
  if ($Found -eq "dark") { return "dark" }
  return "light"
}

function Get-WebAccent {
  param([string]$Hex, $Tokens = $script:WebTokens)
  $out = [ordered]@{ light = $null; dark = $null }
  if (-not $Hex) { return $out }
  foreach ($k in $script:WebThemes) { $out[$k] = Get-AccentPair $Hex $Tokens[$k] }
  return $out
}

function Get-WebLook {
  $sys = Get-WebSystemLook
  $d = Read-DisplayConfig
  $found = Get-DetectedLang
  $lang = Get-PreferredLang
  if (-not $lang) { $lang = $found }
  return [ordered]@{
    lang = $lang; langPref = $d.lang; langFound = $found
    theme = (ConvertTo-WebTheme $d.webTheme $sys.Theme); themePref = $d.webTheme; themeFound = $sys.Theme
    accent = (Get-WebAccent $sys.Accent)
  }
}
