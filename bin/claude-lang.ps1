if (-not (Test-Path Function:\Import-ClmModule)) { . (Join-Path $PSScriptRoot "claude-import.ps1") }
. Import-ClmModule claude-platform, claude-display-config
$script:LangCodes = @("en", "fr")
$script:LangFallback = "en"
$script:LangEnvNames = @("LC_ALL", "LC_MESSAGES", "LANG")
$script:LangMacPattern = New-Object regex '^\s*\(\s*"?([A-Za-z]{2,3}(?:[-_][A-Za-z0-9]+)*)'
$script:LangSystemFound = $null

function ConvertTo-LangCode {
  param($Value)
  $v = ("" + $Value).Trim().Trim('"').ToLowerInvariant()
  if ($v -eq "" -or $v -eq "c" -or $v -eq "posix" -or $v.StartsWith("c.")) { return "" }
  if ($v.StartsWith("fr")) { return "fr" }
  return "en"
}

function ConvertFrom-MacLanguages {
  param([string]$Output)
  $m = $script:LangMacPattern.Match([string]$Output)
  if (-not $m.Success) { return "" }
  return $m.Groups[1].Value
}

function Read-UiCulture {
  return [string][Globalization.CultureInfo]::CurrentUICulture.Name
}

function Read-MacLanguages {
  $r = Invoke-Captured "defaults" "read -g AppleLanguages" 3000
  if ($null -eq $r -or $r.Code -ne 0) { return "" }
  return [string]$r.Out
}

function Read-OsLang {
  param([string]$Os)
  try {
    if ($Os -eq "Windows") { return ConvertTo-LangCode (Read-UiCulture) }
    if ($Os -eq "MacOS") { return ConvertTo-LangCode (ConvertFrom-MacLanguages (Read-MacLanguages)) }
  } catch { return "" }
  return ""
}

function Get-SystemLang {
  param([string]$Os = $script:OsName, $Vars = $null)
  $found = Read-OsLang $Os
  foreach ($name in $script:LangEnvNames) {
    if ($found) { break }
    $found = ConvertTo-LangCode (Read-EnvVar $name $Vars)
  }
  return $found
}

function Get-DetectedLang {
  param([string]$Os = $script:OsName, $Vars = $null)
  $forced = ConvertTo-LangCode (Read-EnvVar "CLM_LANG" $Vars)
  if ($forced) { return $forced }
  if ($null -ne $Vars) { return Get-SystemLang $Os $Vars }
  if ($null -eq $script:LangSystemFound) { $script:LangSystemFound = Get-SystemLang $Os }
  return $script:LangSystemFound
}

function Get-PreferredLang {
  param($Vars = $null)
  $pref = ""
  try { $pref = (Read-DisplayConfig $Vars).lang } catch { $pref = "" }
  if ($script:LangCodes -ccontains $pref) { return $pref }
  return ""
}

function Get-ClmLang {
  param([string]$Os = $script:OsName, $Vars = $null)
  $pref = Get-PreferredLang $Vars
  if ($pref) { return $pref }
  $found = Get-DetectedLang $Os $Vars
  if ($found) { return $found }
  return $script:LangFallback
}
