$script:ClmVersionFile = "clm.version"
$script:ClmRepo = "LetermeFlorent/claude-account-menu"
$script:ClmUnknownText = "version de clm inconnue, pas de mise a jour automatique : telecharge la derniere version sur https://github.com/" + $script:ClmRepo + "/releases, puis lance install.ps1 (install.sh hors Windows)"

function ConvertFrom-ClmVersion {
  param([string]$Text)
  if ($Text -notmatch "^\s*([0-9a-f]{7,40})\s+([0-9]+)(\s+([0-9]+))?\s*$") { return $null }
  return [PSCustomObject]@{ Sha = $Matches[1]; Time = [long]$Matches[2]; Number = [int]$Matches[4] }
}

function Read-ClmVersion {
  param([string]$Dir = $PSScriptRoot)
  $p = Join-Path $Dir $script:ClmVersionFile
  if (-not (Test-Path -LiteralPath $p)) { return $null }
  return ConvertFrom-ClmVersion ([IO.File]::ReadAllText($p))
}

function Test-ClmVersionKnown {
  param($Version)
  return $null -ne $Version -and [int]$Version.Number -gt 0
}

function Format-ClmVersion {
  param($Version)
  if ($null -eq $Version) { return "inconnue" }
  $at = [DateTimeOffset]::FromUnixTimeSeconds($Version.Time).ToLocalTime().ToString("dd/MM/yyyy HH:mm")
  return (Get-ClmName $Version) + " du " + $at
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
  $hint = " : relance clm pour qu'il se mette a jour, puis restaure"
  if ($null -eq $Installed) { return "sauvegarde faite avec clm " + (Format-ClmVersion $Backup) + ", version installee inconnue : reinstalle clm depuis https://github.com/" + $script:ClmRepo + "/releases, puis restaure" }
  if ($Backup.Time -le $Installed.Time) { return $null }
  return "sauvegarde faite avec clm " + (Format-ClmVersion $Backup) + ", plus recent que clm " + (Format-ClmVersion $Installed) + $hint
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
  param([string]$Dir = $PSScriptRoot)
  $v = Read-ClmVersion $Dir
  if ($null -eq $v) { return "" }
  return "clm " + (Get-ClmName $v)
}

function Get-ClmSha {
  param([string]$Dir = $PSScriptRoot)
  $v = Read-ClmVersion $Dir
  if ($null -eq $v) { return "" }
  return $v.Sha
}

function Test-ClmReplaced {
  return (Get-ClmSha) -ne $script:ClmLoadedSha
}

$script:ClmLoadedSha = Get-ClmSha
