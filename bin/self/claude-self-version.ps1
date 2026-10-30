. Import-ClmModule claude-file-io, claude-text
$script:ClmVersionFile = "clm.version"
$script:ClmRepo = "LetermeFlorent/claude-account-menu"
function Get-ClmReleasesUrl {
  return "https://github.com/" + $script:ClmRepo + "/releases"
}

function Get-ClmUnknownText {
  return Get-ClmText "update.self.unknownVersion" @((Get-ClmReleasesUrl))
}

function ConvertFrom-ClmVersion {
  param([string]$Text)
  if ($Text -notmatch "^\s*([0-9a-f]{7,40})\s+([0-9]+)(\s+([0-9]+))?\s*$") { return $null }
  return [PSCustomObject]@{ Sha = $Matches[1]; Time = [long]$Matches[2]; Number = [int]$Matches[4] }
}

function Read-ClmVersion {
  param([string]$Dir = $script:ClmModuleDir)
  $p = Join-Path $Dir $script:ClmVersionFile
  if (-not (Test-Path -LiteralPath $p)) { return $null }
  return ConvertFrom-ClmVersion (Read-SharedText $p)
}

function Test-ClmVersionKnown {
  param($Version)
  return $null -ne $Version -and [int]$Version.Number -gt 0
}

function Format-ClmVersion {
  param($Version)
  if ($null -eq $Version) { return Get-ClmText "update.self.versionNone" }
  $at = [DateTimeOffset]::FromUnixTimeSeconds($Version.Time).ToLocalTime().ToString("dd/MM/yyyy HH:mm")
  return Get-ClmText "update.self.versionAt" @((Get-ClmName $Version), $at)
}

function Test-ClmOutdated {
  param($Installed, $Latest)
  if ($null -eq $Latest -or -not (Test-ClmVersionKnown $Installed)) { return $false }
  return [int]$Latest.Number -gt [int]$Installed.Number
}

function Get-BackupVersion {
  param([string]$Zip)
  Initialize-Tar
  $text = ""
  try { $text = (& $script:Tar -xOf $Zip (".local/bin/" + $script:ClmVersionFile) 2>$null | Out-String) } catch { Write-Verbose $_.Exception.Message }
  return ConvertFrom-ClmVersion $text
}

function Get-BackupVersionError {
  param($Installed, $Backup)
  if ($null -eq $Backup) { return $null }
  if ($null -eq $Installed) { return Get-ClmText "update.self.backupInstalledUnknown" @((Format-ClmVersion $Backup), (Get-ClmReleasesUrl)) }
  if ($Backup.Time -le $Installed.Time) { return $null }
  return Get-ClmText "update.self.backupNewer" @((Format-ClmVersion $Backup), (Format-ClmVersion $Installed))
}

function Assert-BackupVersion {
  param([string]$Zip)
  $msg = Get-BackupVersionError (Read-ClmVersion) (Get-BackupVersion $Zip)
  if ($msg) { throw $msg }
}

function Get-ClmName {
  param($Version)
  if ([int]$Version.Number -gt 0) { return "v" + $Version.Number }
  return $Version.Sha.Substring(0, 7)
}

function Get-ClmTag {
  param([string]$Dir = $script:ClmModuleDir)
  $v = Read-ClmVersion $Dir
  if ($null -eq $v) { return "" }
  return Get-ClmText "update.self.tag" @((Get-ClmName $v))
}

function Get-ClmSha {
  param([string]$Dir = $script:ClmModuleDir)
  $v = Read-ClmVersion $Dir
  if ($null -eq $v) { return "" }
  return $v.Sha
}

function Test-ClmReplaced {
  if ((Read-ClmStamp) -ceq $script:ClmInstallingStamp) { return $false }
  $disk = Get-ClmSha
  return $disk -ne "" -and $disk -ne $script:ClmLoadedSha
}

$script:ClmLoadedSha = Get-ClmSha
