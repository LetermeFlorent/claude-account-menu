if (-not (Test-Path Function:\Import-ClmModule)) { . (Join-Path $PSScriptRoot "claude-import.ps1") }
. Import-ClmModule claude-platform, claude-self-version, claude-self-install

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
  if (-not (Test-ClmVersionKnown $installed)) { throw $script:ClmUnknownText }
  $latest = Get-LatestClm
  if (-not (Test-ClmOutdated $installed $latest)) { return $null }
  return $latest
}

function Update-Clm {
  if (-not (Test-ClmInstalledHere)) { return $false }
  if (-not (Test-ClmVersionKnown (Read-ClmVersion))) {
    Write-Host ("  " + $script:ClmUnknownText) -ForegroundColor DarkYellow
    return $false
  }
  $latest = $null
  try { $latest = Find-ClmUpdate } catch { return $false }
  if ($null -eq $latest) { return $false }
  Write-Host ("  nouvelle version de clm (" + (Format-ClmVersion $latest) + "), installation...") -ForegroundColor DarkGray
  try { Install-ClmVersion $latest }
  catch {
    Write-Host ("  mise a jour de clm impossible : " + $_.Exception.Message) -ForegroundColor DarkYellow
    return $false
  }
  Write-Host "  clm mis a jour, redemarrage" -ForegroundColor DarkGray
  return $true
}

function Restart-Clm {
  param([string]$Script, [string[]]$Argv)
  $exe = (Get-Process -Id $PID).Path
  & $exe -NoProfile -ExecutionPolicy Bypass -File $Script @Argv "--updated"
  exit $LASTEXITCODE
}
