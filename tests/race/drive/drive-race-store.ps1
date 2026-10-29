$script:DriveRaceFileRel = ".claude/settings.json"
$script:DriveRaceFileText = "reglages de la course Drive"

function Get-DriveRaceKeys {
  return New-SyncKeys ([byte[]](10..41)) ([byte[]](1..16)) 600000
}

function Get-DriveRaceMd5 {
  param([byte[]]$Bytes, $Props)
  if ($Props["h"]) { return [string]$Props["h"] }
  $md5 = [Security.Cryptography.MD5]::Create()
  try { return -join ($md5.ComputeHash($Bytes) | ForEach-Object { $_.ToString("x2") }) } finally { $md5.Dispose() }
}

function Read-DriveRaceEntry {
  param([string]$Path)
  try { $data = (Read-SharedText $Path) | ConvertFrom-Json }
  catch { if ([IO.File]::Exists($Path)) { throw } else { return $null } }
  $props = @{}
  if ($null -ne $data.Props) { foreach ($p in $data.Props.PSObject.Properties) { $props[$p.Name] = [string]$p.Value } }
  $bytes = [Convert]::FromBase64String([string]$data.Data)
  $folder = Split-Path -Leaf (Split-Path -Parent $Path)
  return @{ Id = [string]$data.Id; Name = [string]$data.Name; Folder = $folder; Md5 = (Get-DriveRaceMd5 $bytes $props); M = [long]$props["m"]; Pc = [string]$props["pc"]; Exp = [long]$props["exp"]; Props = $props; Bytes = $bytes }
}

function Read-DriveRaceEntries {
  param([string]$Store, [string]$FolderId)
  $dir = Join-Path $Store $FolderId
  $out = @()
  if (-not [IO.Directory]::Exists($dir)) { return ,$out }
  foreach ($path in [IO.Directory]::GetFiles($dir)) {
    if (-not $path.EndsWith(".json")) { continue }
    $e = Read-DriveRaceEntry $path
    if ($null -ne $e) { $out += $e }
  }
  return ,$out
}

function Find-DriveRaceFile {
  param([string]$Store, [string]$Id)
  if (-not [IO.Directory]::Exists($Store)) { return $null }
  foreach ($dir in [IO.Directory]::GetDirectories($Store)) {
    $path = Join-Path $dir ($Id + ".json")
    if ([IO.File]::Exists($path)) { return $path }
  }
  return $null
}

function Write-DriveRaceEntry {
  param([string]$Store, [string]$FolderId, [string]$Id, [string]$Name, $Props, [byte[]]$Bytes)
  $dir = Join-Path $Store $FolderId
  $null = [IO.Directory]::CreateDirectory($dir)
  if ($null -eq $Bytes) { $Bytes = [byte[]]@() }
  $data = [ordered]@{ Id = $Id; Name = $Name; Props = $Props; Data = [Convert]::ToBase64String($Bytes) }
  Write-TextFileAtomic (Join-Path $dir ($Id + ".json")) (ConvertTo-Json $data -Compress -Depth 4)
  return @{ Id = $Id; Md5 = (Get-DriveRaceMd5 $Bytes $Props) }
}
