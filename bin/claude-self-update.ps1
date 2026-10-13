. (Join-Path $PSScriptRoot "claude-platform.ps1")
. (Join-Path $PSScriptRoot "claude-self-version.ps1")
$script:ClmRepo = "LetermeFlorent/claude-account-menu"

function ConvertFrom-CommitJson {
  param([string]$Json)
  if ($Json -notmatch '^\s*\{\s*"sha"\s*:\s*"([0-9a-f]{40})"') { return $null }
  $sha = $Matches[1]
  if ($Json -notmatch '"committer"\s*:\s*\{[^{}]*"date"\s*:\s*"([^"]+)"') { return $null }
  $at = [DateTimeOffset]::Parse($Matches[1], [Globalization.CultureInfo]::InvariantCulture)
  return [PSCustomObject]@{ Sha = $sha; Time = $at.ToUnixTimeSeconds() }
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
  $r = Invoke-GitHubGet ("https://api.github.com/repos/" + $script:ClmRepo + "/commits/main") 4
  return ConvertFrom-CommitJson ("" + $r.Content)
}

function Test-ClmInstalledHere {
  $dir = Join-Path (Get-HomeDir) (Join-Path ".local" "bin")
  return (ConvertTo-PathKey $PSScriptRoot) -eq (ConvertTo-PathKey $dir)
}

function Invoke-ClmInstaller {
  param([string]$Src)
  if ($script:OsName -eq "Windows") { $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Src "install.ps1") 2>&1 }
  else { $out = & sh (Join-Path $Src "install.sh") 2>&1 }
  if ($LASTEXITCODE -ne 0) { throw ("installeur en echec : " + ("" + (@($out) | Select-Object -Last 1))) }
}

function Install-ClmVersion {
  param($Version)
  $tmp = Join-Path ([IO.Path]::GetTempPath()) ("clm-update-" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $tmp | Out-Null
  try {
    $zip = Join-Path $tmp "clm.zip"
    $null = Invoke-GitHubGet ("https://codeload.github.com/" + $script:ClmRepo + "/zip/" + $Version.Sha) 60 $zip
    Expand-Archive -LiteralPath $zip -DestinationPath $tmp
    $src = Get-ChildItem -LiteralPath $tmp -Directory | Select-Object -First 1
    Invoke-ClmInstaller $src.FullName
    Write-ClmVersion $Version
  } finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function Update-Clm {
  if (-not (Test-ClmInstalledHere)) { return $false }
  $latest = $null
  try { $latest = Get-LatestClm } catch { return $false }
  if (-not (Test-ClmOutdated (Read-ClmVersion) $latest)) { return $false }
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
