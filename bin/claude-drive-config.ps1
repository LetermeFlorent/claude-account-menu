if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-platform.ps1")) { . (Join-Path $PSScriptRoot "claude-platform.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-json.ps1")) { . (Join-Path $PSScriptRoot "claude-json.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-state.ps1")) { . (Join-Path $PSScriptRoot "claude-state.ps1") }
$script:DriveConfigPath = Get-StatePath "drive.json"

function Read-DriveConfig {
  try { $data = Read-JsonFile $script:DriveConfigPath } catch { return $null }
  if ($null -eq $data) { return $null }
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
  $c = Read-DriveConfig
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
  $c = Read-DriveConfig
  if ($null -ne $c -and -not [string]::IsNullOrEmpty([string]$c["pc"])) { return [string]$c["pc"] }
  return [Environment]::MachineName
}

function Clear-DriveFolders {
  param($Config)
  foreach ($k in @("folderRoot", "folderFiles", "folderCredentials", "folderPresence", "lastSync")) { $Config.Remove($k) }
}
