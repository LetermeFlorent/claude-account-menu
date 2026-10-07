. (Join-Path $PSScriptRoot "claude-platform.ps1")
$script:VersionPattern = "(\d+\.\d+\.\d+(?:-[0-9A-Za-z]+(?:\.[0-9A-Za-z]+)*)?)"
$script:CheckTimeout = 20
$script:StallTimeout = 90

function ConvertFrom-UpdateLine {
  param([string]$Line)
  $t = ("" + $Line).Trim()
  $v = $script:VersionPattern
  if ($t -match ("^Current version:\s*" + $v)) { return @{ Kind = "current"; Version = $Matches[1] } }
  if ($t -match ("^Claude Code is up to date \(" + $v)) { return @{ Kind = "uptodate"; Version = $Matches[1] } }
  if ($t -match "^Claude is up to date") { return @{ Kind = "uptodate"; Version = $null } }
  if ($t -match ("^Updating to " + $v)) { return @{ Kind = "native"; Version = $Matches[1] } }
  if ($t -match ("^(?:New version available:|Downgrading to)\s*" + $v)) { return @{ Kind = "package"; Version = $Matches[1] } }
  if ($t -match "^Installing update") { return @{ Kind = "package"; Version = $null } }
  if ($t -match ("^Successfully (?:updated|downgraded) from " + $v + " to version " + $v)) { return @{ Kind = "success"; From = $Matches[1]; Version = $Matches[2] } }
  if ($t -match ("^Update available:\s*" + $v)) { return @{ Kind = "manual"; Version = $Matches[1] } }
  if ($t -match "^Claude is managed by (.+?)\.?$") { return @{ Kind = "manager"; Name = $Matches[1] } }
  if ($t -match "is currently running|currently performing an update") { return @{ Kind = "busy" } }
  if ($t -match "^(Error|Failed|Unable|Could not)") { return @{ Kind = "error"; Text = $t } }
  return @{ Kind = "other"; Text = $t }
}

function New-UpdateState {
  return @{ Current = $null; Target = $null; Mode = $null; Done = $null; From = $null; Manager = $null; Busy = $false; Error = $null; Last = "" }
}

function Add-UpdateLine {
  param($State, [string]$Line)
  $e = ConvertFrom-UpdateLine $Line
  if (("" + $Line).Trim() -ne "") { $State.Last = $Line.Trim() }
  $k = $e.Kind
  if ($k -eq "current") { $State.Current = $e.Version }
  elseif ($k -eq "uptodate") { $State.Done = "uptodate"; if ($e.Version) { $State.Current = $e.Version } }
  elseif ($k -eq "native") { $State.Mode = "native"; $State.Target = $e.Version }
  elseif ($k -eq "package") { if (-not $State.Mode) { $State.Mode = "package" }; if ($e.Version) { $State.Target = $e.Version } }
  elseif ($k -eq "success") { $State.Done = "updated"; $State.From = $e.From; $State.Target = $e.Version }
  elseif ($k -eq "manual") { $State.Done = "manual"; $State.Target = $e.Version }
  elseif ($k -eq "manager") { $State.Manager = $e.Name }
  elseif ($k -eq "busy") { $State.Busy = $true }
  elseif ($k -eq "error" -and -not $State.Error) { $State.Error = $e.Text }
}

function Limit-Text {
  param([string]$Text, [int]$Max)
  if ($Text.Length -le $Max) { return $Text }
  return $Text.Substring(0, $Max - 3) + "..."
}

function New-Outcome {
  param([string]$Kind, [string]$Text)
  return [PSCustomObject]@{ Kind = $Kind; Text = $Text }
}

function Get-UpdateOutcome {
  param($State, [int]$ExitCode, [string]$Killed)
  if ($Killed -eq "check") { return New-Outcome "failed" "mise a jour de Claude Code : verification impossible" }
  if ($Killed -eq "stall") { return New-Outcome "failed" "mise a jour de Claude Code abandonnee, telechargement bloque" }
  if ($State.Done -eq "updated") {
    $from = $State.From
    if (-not $from) { $from = $State.Current }
    return New-Outcome "updated" ("Claude Code mis a jour, " + $from + " -> " + $State.Target)
  }
  if ($State.Done -eq "uptodate") {
    $txt = "Claude Code a jour"
    if ($State.Current) { $txt += " (" + $State.Current + ")" }
    return New-Outcome "ok" $txt
  }
  if ($State.Done -eq "manual") {
    $by = "le gestionnaire de paquets"
    if ($State.Manager) { $by = $State.Manager }
    return New-Outcome "manual" ("Claude Code " + $State.Target + " disponible, a installer avec " + $by)
  }
  if ($State.Busy) { return New-Outcome "failed" "mise a jour de Claude Code deja en cours ailleurs" }
  if ($State.Error) { return New-Outcome "failed" ("echec de la mise a jour : " + (Limit-Text $State.Error 50)) }
  if ($ExitCode -ne 0) { return New-Outcome "failed" ("echec de claude update (code " + $ExitCode + ")") }
  if ($State.Last) { return New-Outcome "unknown" ("claude update : " + (Limit-Text $State.Last 50)) }
  return New-Outcome "unknown" "claude update termine"
}

function Get-DownloadPercent {
  param([long]$Bytes, [long]$Size)
  if ($Size -le 0 -or $Bytes -lt 0) { return -1 }
  return [int][math]::Min(100, [math]::Floor($Bytes * 100 / $Size))
}

function Format-DownloadDetail {
  param([long]$Bytes, [long]$Size)
  $got = "" + [math]::Floor([math]::Max(0, $Bytes) / 1MB)
  if ($Size -gt 0) { return $got + " / " + [math]::Floor($Size / 1MB) + " Mo" }
  return $got + " Mo"
}

function Get-ManifestPlatform {
  param([string]$Os, [string]$Arch, [bool]$Musl = $false)
  $a = "x64"
  if ($Arch -match "^(arm64|aarch64)$") { $a = "arm64" }
  if ($Os -eq "Windows") { return "win32-" + $a }
  if ($Os -eq "MacOS") { return "darwin-" + $a }
  if ($Musl) { return "linux-" + $a + "-musl" }
  return "linux-" + $a
}

function Get-ManifestEntry {
  param($Manifest, [string]$Platform)
  if ($Manifest -eq $null -or $Manifest.platforms -eq $null) { return $null }
  $e = $Manifest.platforms.$Platform
  if ($e -eq $null) { return $null }
  return [PSCustomObject]@{ Size = [long]$e.size; Binary = [string]$e.binary }
}

function Get-StagingRoot {
  param([string]$Os = $script:OsName, $Vars = $null)
  $cache = Read-EnvVar "XDG_CACHE_HOME" $Vars
  if ($cache -eq "") {
    $h = Read-EnvVar "HOME" $Vars
    if ($h -eq "") { $h = Get-HomeDir $Vars }
    $cache = Join-OsPath $Os @($h, ".cache")
  }
  return Join-OsPath $Os @($cache, "claude", "staging")
}

function Test-StagingDirName {
  param([string]$Name, [string]$Version, [int]$ProcessId)
  return ($Name -eq $Version -or $Name.StartsWith($Version + "." + $ProcessId + "."))
}

function Get-WatchAction {
  param([double]$Elapsed, [bool]$Started, [bool]$Seen, [bool]$Settled, [double]$Idle)
  if (-not $Started) {
    if ($Elapsed -ge $script:CheckTimeout) { return "check" }
    return ""
  }
  if ($Seen -and -not $Settled -and $Idle -ge $script:StallTimeout) { return "stall" }
  return ""
}
