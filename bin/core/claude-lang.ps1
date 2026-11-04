if (-not (Test-Path Function:\Import-ClmModule)) { . (Join-Path $PSScriptRoot "../claude-import.ps1") }
. Import-ClmModule claude-platform, claude-display-config
$script:LangCodes = @("en", "fr")
$script:LangFallback = "en"
$script:LangEnvNames = @("LC_ALL", "LC_MESSAGES", "LANG")
$script:LangMacPattern = New-Object regex '^\s*\(\s*"?([A-Za-z]{2,3}(?:[-_][A-Za-z0-9]+)*)'
$script:LangSystemFound = $null
$script:LangPrefTicks = [Diagnostics.Stopwatch]::Frequency

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

function Read-PreferredLang {
  param($Vars = $null)
  $pref = ""
  try { $pref = (Read-DisplayConfig $Vars).lang } catch { $pref = "" }
  if ($script:LangCodes -ccontains $pref) { return $pref }
  return ""
}

function Get-LangPrefStamp {
  try {
    $info = New-Object IO.FileInfo (Get-DisplayPath)
    if (-not $info.Exists) { return $info.FullName + "|none" }
    return $info.FullName + "|" + $info.LastWriteTimeUtc.Ticks + ":" + $info.Length
  } catch { return "" }
}

function Get-PreferredLang {
  param($Vars = $null)
  if ($null -ne $Vars) { return Read-PreferredLang $Vars }
  $now = [Diagnostics.Stopwatch]::GetTimestamp()
  $where = "" + $env:HOME + "|" + $env:USERPROFILE + "|" + $env:LOCALAPPDATA + "|" + $env:XDG_STATE_HOME
  $hit = $script:LangPrefCache
  if ($null -ne $hit -and $hit.Where -ceq $where -and $now - $hit.At -lt $script:LangPrefTicks) { return $hit.Lang }
  $stamp = Get-LangPrefStamp
  if ($stamp -and $null -ne $hit -and $hit.Stamp -ceq $stamp) { $hit.At = $now; $hit.Where = $where; return $hit.Lang }
  $lang = Read-PreferredLang
  $script:LangPrefCache = @{ Stamp = $stamp; Lang = $lang; At = $now; Where = $where }
  return $lang
}

function Get-ClmLang {
  param([string]$Os = $script:OsName, $Vars = $null)
  if ($null -eq $Vars) {
    $now = [Diagnostics.Stopwatch]::GetTimestamp()
    $where = "" + $Os + "|" + $env:CLM_LANG + "|" + $env:HOME + "|" + $env:USERPROFILE + "|" + $env:LOCALAPPDATA + "|" + $env:XDG_STATE_HOME
    $hit = $script:LangMemo
    if ($null -ne $hit -and $hit.Where -ceq $where -and $now - $hit.At -lt $script:LangPrefTicks -and [object]::ReferenceEquals($hit.Pref, $script:LangPrefCache) -and $hit.Sys -ceq $script:LangSystemFound) { return $hit.Lang }
  }
  $lang = Get-PreferredLang $Vars
  if (-not $lang) { $lang = Get-DetectedLang $Os $Vars }
  if (-not $lang) { $lang = $script:LangFallback }
  if ($null -eq $Vars) { $script:LangMemo = @{ Where = $where; At = $now; Lang = $lang; Pref = $script:LangPrefCache; Sys = $script:LangSystemFound } }
  return $lang
}
