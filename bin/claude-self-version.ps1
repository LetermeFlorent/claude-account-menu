$script:ClmVersionFile = "clm.version"

function ConvertFrom-ClmVersion {
  param([string]$Text)
  if ($Text -notmatch "^\s*([0-9a-f]{7,40})\s+([0-9]+)(\s+([0-9]+))?\s*$") { return $null }
  return [PSCustomObject]@{ Sha = $Matches[1]; Time = [long]$Matches[2]; Count = [int]$Matches[4] }
}

function Read-ClmVersion {
  param([string]$Dir = $PSScriptRoot)
  $p = Join-Path $Dir $script:ClmVersionFile
  if (-not (Test-Path -LiteralPath $p)) { return $null }
  return ConvertFrom-ClmVersion ([IO.File]::ReadAllText($p))
}

function Write-ClmVersion {
  param($Version, [string]$Dir = $PSScriptRoot)
  $text = $Version.Sha + " " + $Version.Time
  if ([int]$Version.Count -gt 0) { $text += " " + $Version.Count }
  $text += "`n"
  [IO.File]::WriteAllText((Join-Path $Dir $script:ClmVersionFile), $text, (New-Object Text.UTF8Encoding $false))
}

function Format-ClmVersion {
  param($Version)
  if ($null -eq $Version) { return "inconnue" }
  $at = [DateTimeOffset]::FromUnixTimeSeconds($Version.Time).ToLocalTime().ToString("dd/MM/yyyy HH:mm")
  return (Get-ClmName $Version) + " du " + $at
}

function Test-ClmOutdated {
  param($Installed, $Latest)
  if ($null -eq $Latest) { return $false }
  if ($null -eq $Installed) { return $true }
  return ($Latest.Sha -ne $Installed.Sha) -and ($Latest.Time -gt $Installed.Time)
}

function Get-BackupVersion {
  param([string]$Zip)
  Initialize-Tar
  $text = ""
  try { $text = (& $script:Tar -xOf $Zip (".local/bin/" + $script:ClmVersionFile) 2>$null | Out-String) } catch {}
  return ConvertFrom-ClmVersion $text
}

function Get-BackupVersionError {
  param($Installed, $Backup)
  if ($null -eq $Backup) { return $null }
  $hint = " : relance clm pour qu'il se mette a jour, puis restaure"
  if ($null -eq $Installed) { return "sauvegarde faite avec clm " + (Format-ClmVersion $Backup) + ", version installee inconnue" + $hint }
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
  if ([int]$Version.Count -gt 0) { return "v" + $Version.Count }
  return $Version.Sha.Substring(0, 7)
}

function Get-ClmTag {
  param([string]$Dir = $PSScriptRoot)
  $v = Read-ClmVersion $Dir
  if ($null -eq $v) { return "" }
  return "clm " + (Get-ClmName $v)
}
