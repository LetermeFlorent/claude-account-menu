if (-not (Test-Path Function:\Import-ClmModule)) { . (Join-Path $PSScriptRoot "../claude-import.ps1") }
. Import-ClmModule claude-machine-lock
$script:ClmRepo = "LetermeFlorent/claude-account-menu"
$script:ClmLatestStamp = "clm-latest"

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
  $latest = ConvertFrom-ReleaseJson ("" + $r.Content)
  if ($null -ne $latest) { try { $null = Write-MachineStamp $script:ClmLatestStamp ("" + $latest.Number) } catch { Write-Verbose $_.Exception.Message } }
  return $latest
}
