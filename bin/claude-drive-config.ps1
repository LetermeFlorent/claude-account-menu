if (-not (Test-Path Function:\Import-ClmModule)) { . (Join-Path $PSScriptRoot "claude-import.ps1") }
. Import-ClmModule claude-platform, claude-json, claude-state, claude-text
$script:DriveConfigPath = Get-StatePath "drive.json"

function Read-DriveConfig {
  if (-not (Test-Path -LiteralPath $script:DriveConfigPath)) { return $null }
  try { $data = Read-JsonFile $script:DriveConfigPath } catch { $data = $null }
  if ($data -isnot [Collections.IDictionary]) { throw (Get-ClmText "drive.config.unreadable" @($script:DriveConfigPath)) }
  $out = @{}
  foreach ($k in @($data.Keys)) { $out[$k] = $data[$k] }
  return $out
}

function Save-DriveConfig {
  param($Config)
  $ordered = [ordered]@{}
  foreach ($k in @($Config.Keys | Sort-Object)) { $ordered[$k] = $Config[$k] }
  Write-TextFileAtomic $script:DriveConfigPath ((ConvertTo-JsonText $ordered) + "`n") -Private
}

function Test-DriveConnected {
  try { $c = Read-DriveConfig } catch { return $false }
  return $null -ne $c -and -not [string]::IsNullOrEmpty([string]$c["refreshToken"])
}

function Test-DriveAuto {
  if (-not (Test-DriveConnected)) { return $false }
  return (Read-DriveConfig)["auto"] -ne $false
}

function Set-DriveAuto {
  param([bool]$On)
  $c = Read-DriveConfig
  if ($null -eq $c) { $c = @{} }
  $c["auto"] = $On
  Save-DriveConfig $c
}

function Get-DrivePcName {
  try { $c = Read-DriveConfig } catch { return [Environment]::MachineName }
  if ($null -ne $c -and -not [string]::IsNullOrEmpty([string]$c["pc"])) { return [string]$c["pc"] }
  return [Environment]::MachineName
}

function Get-DriveLastSync {
  try { $c = Read-DriveConfig } catch { return [long]0 }
  if ($null -eq $c) { return [long]0 }
  return [long]$c["lastSync"]
}

function Clear-DriveFolders {
  param($Config)
  foreach ($k in @("folderRoot", "folderFiles", "folderCredentials", "folderPresence", "lastSync")) { $Config.Remove($k) }
}
