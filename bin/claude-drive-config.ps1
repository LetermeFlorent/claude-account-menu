if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-platform.ps1")) { . (Join-Path $PSScriptRoot "claude-platform.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-json.ps1")) { . (Join-Path $PSScriptRoot "claude-json.ps1") }
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
  $tmp = $script:DriveConfigPath + "." + [guid]::NewGuid().ToString("N") + ".tmp"
  [IO.File]::WriteAllText($tmp, (ConvertTo-JsonText $ordered) + "`n", (New-Object Text.UTF8Encoding $false))
  if ($script:OsName -ne "Windows") { try { & chmod 600 $tmp } catch {} }
  if (Test-Path -LiteralPath $script:DriveConfigPath) { [IO.File]::Replace($tmp, $script:DriveConfigPath, [NullString]::Value) }
  else { [IO.File]::Move($tmp, $script:DriveConfigPath) }
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

function Invoke-WithFileLock {
  param([string]$Path, [int]$WaitMs, [string]$Message, [scriptblock]$Action)
  $deadline = [DateTime]::UtcNow.AddMilliseconds($WaitMs)
  while ($true) {
    try { $fs = [IO.File]::Open($Path, "OpenOrCreate", "ReadWrite", "None"); break }
    catch {
      if ([DateTime]::UtcNow -ge $deadline) { throw $Message }
      Start-Sleep -Milliseconds 200
    }
  }
  try { & $Action } finally { $fs.Dispose() }
}
