if (-not (Test-Path Function:\Import-ClmModule)) { . (Join-Path $PSScriptRoot "claude-import.ps1") }
. Import-ClmModule claude-platform, claude-self-version, claude-self-install, claude-machine-lock, claude-text
$script:ClmUpdateLock = "clm-update"
$script:ClmCheckStamp = "clm-check"
$script:ClmUpdateWaitMs = 180000
$script:ClmCheckFreshMs = 120000

function ConvertFrom-ReleaseJson {
  param([string]$Json)
  if ($Json -notmatch '"tag_name"\s*:\s*"v([0-9]{1,9})"') { return $null }
  $number = [int]$Matches[1]
  if ($Json -notmatch '"published_at"\s*:\s*"([^"]+)"') { return $null }
  $at = [DateTimeOffset]::Parse($Matches[1], [Globalization.CultureInfo]::InvariantCulture)
  return [PSCustomObject]@{ Sha = ""; Time = $at.ToUnixTimeSeconds(); Number = $number }
}

function Invoke-GitHubGet {
  param([string]$Uri, [int]$Timeout, [string]$OutFile = "")
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  $req = @{ Uri = $Uri; UseBasicParsing = $true; TimeoutSec = $Timeout; Headers = @{ "User-Agent" = "clm" } }
  if ($OutFile) { $req["OutFile"] = $OutFile }
  $saved = $ProgressPreference
  $ProgressPreference = "SilentlyContinue"
  try { return Invoke-WebRequest @req } finally { $ProgressPreference = $saved }
}

function Get-LatestClm {
  $r = Invoke-GitHubGet ("https://api.github.com/repos/" + $script:ClmRepo + "/releases/latest") 4
  return ConvertFrom-ReleaseJson ("" + $r.Content)
}

function Test-ClmInstalledHere {
  $dir = Join-Path (Get-HomeDir) (Join-Path ".local" "bin")
  return (ConvertTo-PathKey $PSScriptRoot) -eq (ConvertTo-PathKey $dir)
}

function Find-ClmUpdate {
  $installed = Read-ClmVersion
  if (-not (Test-ClmVersionKnown $installed)) { throw (Get-ClmUnknownText) }
  $latest = Get-LatestClm
  if (-not (Test-ClmOutdated $installed $latest)) { return $null }
  return $latest
}

function Get-ClmUpdateSkip {
  param([string]$LoadedSha)
  $disk = Get-ClmSha
  if (-not $disk) { return "" }
  if ($disk -ne $LoadedSha) { return "replaced" }
  if ((Read-MachineStamp $script:ClmCheckStamp $script:ClmCheckFreshMs) -ceq $disk) { return "fresh" }
  return ""
}

function Write-ClmChecked {
  $sha = Get-ClmSha
  if ($sha) { Write-MachineStamp $script:ClmCheckStamp $sha }
}

function Update-Clm {
  param([switch]$Recheck)
  if (-not (Test-ClmInstalledHere)) { return $false }
  if (-not (Test-ClmVersionKnown (Read-ClmVersion))) {
    Write-Host ("  " + (Get-ClmUnknownText)) -ForegroundColor DarkYellow
    return $false
  }
  $lock = Open-MachineLock $script:ClmUpdateLock
  if ($null -eq $lock) {
    Write-Host ("  " + (Get-ClmText "update.self.waitPeer")) -ForegroundColor DarkGray
    $lock = Open-MachineLock $script:ClmUpdateLock $script:ClmUpdateWaitMs
  }
  if ($null -eq $lock) { return $false }
  try { return Update-ClmLocked $Recheck.IsPresent } finally { Close-MachineLock $lock }
}

function Update-ClmLocked {
  param([bool]$Recheck)
  $skip = Get-ClmUpdateSkip $script:ClmLoadedSha
  if ($skip -eq "replaced") {
    Write-Host ("  " + (Get-ClmText "update.self.replacedByPeer")) -ForegroundColor DarkGray
    return $true
  }
  if ($skip -eq "fresh" -and -not $Recheck) { return $false }
  $latest = $null
  try { $latest = Find-ClmUpdate } catch { return $false }
  if ($null -eq $latest) { Write-ClmChecked; return $false }
  Write-Host ("  " + (Get-ClmText "update.self.found" @((Format-ClmVersion $latest)))) -ForegroundColor DarkGray
  try { Install-ClmVersion $latest }
  catch {
    Write-Host ("  " + (Get-ClmText "update.self.failed" @($_.Exception.Message))) -ForegroundColor DarkYellow
    return $false
  }
  Write-Host ("  " + (Get-ClmText "update.self.done")) -ForegroundColor DarkGray
  return $true
}

function Restart-Clm {
  param([string]$Script, [string[]]$Argv)
  if ($script:ClmRestartDue) { $Argv = Get-ClmRestartArgs $Argv }
  $exe = (Get-Process -Id $PID).Path
  & $exe -NoProfile -ExecutionPolicy Bypass -File $Script @Argv "--updated"
  exit $LASTEXITCODE
}
