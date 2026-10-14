. (Join-Path $PSScriptRoot "claude-platform.ps1")
. (Join-Path $PSScriptRoot "claude-json.ps1")
$script:DriveConfigPath = Join-Path (Get-HomeDir) ".clm-drive.json"

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
  [IO.File]::WriteAllText($script:DriveConfigPath, (ConvertTo-JsonText $ordered) + "`n", (New-Object Text.UTF8Encoding $false))
  if ($script:OsName -ne "Windows") { try { & chmod 600 $script:DriveConfigPath } catch {} }
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
