$syncSaved = @($script:HomeDir, $script:RegistryPath, $script:DriveStatePath, $script:DriveConfigPath, $script:DriveLockPath, $script:DriveLockWaitMs, $script:DriveParallel, $script:DriveSessionDir, $script:SyncChoicePath, $script:SyncChoiceLockPath, $script:SyncCatalogPath, $script:SyncChoiceWaitMs)
$script:DriveParallel = 1
$script:Fake = New-PathMap
$script:FakePresence = New-PathMap
$script:FakeSeq = 0
$script:FailSend = @()
$script:StopAfter = 0
$script:StopCtl = $null
$script:FakeRoot = "R"
$script:OnMedia = $null
$script:OnSend = $null

function Get-FakeMd5 {
  param([byte[]]$Bytes)
  $md5 = [Security.Cryptography.MD5]::Create()
  try { return -join ($md5.ComputeHash($Bytes) | ForEach-Object { $_.ToString("x2") }) } finally { $md5.Dispose() }
}

function Get-FakeText {
  param([string]$Name)
  return [Text.Encoding]::UTF8.GetString($script:Fake[$Name].Bytes)
}

function Find-FakeName {
  param([string]$Id)
  foreach ($k in $script:Fake.Keys) { if ($script:Fake[$k].Id -eq $Id) { return $k } }
  return $null
}

function Get-DriveFolders { return @{ Root = $script:FakeRoot; Files = "F"; Credentials = "C"; Presence = "P" } }
function Sync-DriveCredentials { param($Folders, $Accs) return 0 }
function Get-DriveListing {
  param([string]$FolderId)
  $m = New-PathMap
  if ($FolderId -eq "F") { foreach ($k in $script:Fake.Keys) { $m[$k] = $script:Fake[$k] } }
  if ($FolderId -eq "P") { foreach ($k in $script:FakePresence.Keys) { $m[$k] = $script:FakePresence[$k] } }
  return $m
}
function Get-DriveFilesListing { param($Folders, [string]$Pc) return Get-DriveListing $Folders.Files }
function Send-DriveContent {
  param([string]$FolderId, [string]$Name, [byte[]]$Bytes, $Props, [string]$Id)
  if ($FolderId -eq "P") { return Send-FakePresence $Name $Bytes $Props }
  if ($null -ne $script:OnSend) { & $script:OnSend $Name }
  if ($script:FailSend -contains $Name) { throw "panne reseau" }
  if ($Id) { $Name = Find-FakeName $Id } else { $script:FakeSeq++; $Id = "id" + $script:FakeSeq }
  $md5 = Get-FakeMd5 $Bytes
  $script:Fake[$Name] = @{ Id = $Id; Name = $Name; Md5 = $md5; M = [long]$Props["m"]; Pc = [string]$Props["pc"]; Exp = 0; Props = $Props; Bytes = $Bytes }
  if ($script:StopAfter -gt 0) {
    $script:StopAfter--
    if ($script:StopAfter -eq 0) { $script:StopCtl.Stop = $true }
  }
  return @{ Id = $Id; Md5 = $md5 }
}
function Send-FakePresence {
  param([string]$Name, [byte[]]$Bytes, $Props)
  $old = $script:FakePresence[$Name]
  $all = @{}
  if ($null -ne $old) { foreach ($k in $old.Props.Keys) { $all[$k] = $old.Props[$k] } }
  foreach ($k in $Props.Keys) { $all[$k] = $Props[$k] }
  $md5 = Get-FakeMd5 $Bytes
  $script:FakePresence[$Name] = @{ Id = ("p-" + $Name); Name = $Name; Props = $all; Bytes = $Bytes; Md5 = $md5 }
  return @{ Id = ("p-" + $Name); Md5 = $md5 }
}
function Get-DriveText {
  param([string]$Id)
  foreach ($k in $script:FakePresence.Keys) {
    $e = $script:FakePresence[$k]
    if ($e.Id -ne $Id) { continue }
    if ($null -eq $e.Bytes) { return "{}" }
    return [Text.Encoding]::UTF8.GetString($e.Bytes)
  }
  return Get-FakeText (Find-FakeName $Id)
}
function Save-DriveMedia {
  param([string]$Id, [string]$Path)
  [IO.File]::WriteAllBytes($Path, $script:Fake[(Find-FakeName $Id)].Bytes)
  if ($null -ne $script:OnMedia) { & $script:OnMedia }
}
function Remove-DriveFile { param([string]$Id) $script:Fake.Remove((Find-FakeName $Id)) }
function Remove-DriveFiles {
  param([string[]]$Ids, $Ctl, [long]$DeadlineMs)
  if (Test-SyncStop $Ctl $DeadlineMs) { return 0 }
  foreach ($id in $Ids) { Remove-DriveFile $id }
  return $Ids.Count
}
function Set-DriveProps {
  param([string]$Id, $Props)
  foreach ($k in $script:FakePresence.Keys) { if ($script:FakePresence[$k].Id -eq $Id) { foreach ($p in $Props.Keys) { $script:FakePresence[$k].Props[$p] = $Props[$p] } } }
}

function Use-Pc {
  param([string]$Name)
  $script:HomeDir = Join-Path $script:Sandbox ("pc-" + $Name)
  if (-not (Test-Path -LiteralPath $script:HomeDir)) { New-Item -ItemType Directory -Path $script:HomeDir -Force | Out-Null }
  $script:RegistryPath = Join-Path $script:HomeDir ".claude-accounts.json"
  $script:DriveStatePath = Join-Path $script:HomeDir ".clm-drive-state.json"
  $script:DriveConfigPath = Join-Path $script:HomeDir ".clm-drive.json"
  $script:DriveLockPath = Join-Path $script:HomeDir ".clm-drive.lock"
  $script:DriveSessionDir = Join-Path $script:HomeDir ".clm-drive-watch"
  $script:SyncChoicePath = Join-Path $script:HomeDir ".clm-sync-choice.json"
  $script:SyncChoiceLockPath = Join-Path $script:HomeDir ".clm-sync-choice.lock"
  $script:SyncCatalogPath = Join-Path $script:HomeDir ".clm-sync-catalog.json"
  $script:SyncChoiceWaitMs = 0
  Save-DriveConfig @{ refreshToken = "r"; pc = $Name }
}

function Set-PcFile {
  param([string]$Rel, [string]$Text, [long]$M = 0)
  $p = Join-Path $script:HomeDir $Rel
  New-Item -ItemType Directory -Path (Split-Path -Parent $p) -Force | Out-Null
  [IO.File]::WriteAllText($p, $Text)
  if ($M -gt 0) { [IO.File]::SetLastWriteTimeUtc($p, [DateTimeOffset]::FromUnixTimeSeconds($M).UtcDateTime) }
}

function Get-PcText {
  param([string]$Rel)
  $p = Join-Path $script:HomeDir $Rel
  if (-not (Test-Path -LiteralPath $p)) { return $null }
  return [IO.File]::ReadAllText($p)
}

$script:DriveLockWaitMs = 0

function Restore-FakeDrive {
  $script:HomeDir, $script:RegistryPath, $script:DriveStatePath, $script:DriveConfigPath, $script:DriveLockPath, $script:DriveLockWaitMs, $script:DriveParallel, $script:DriveSessionDir, $script:SyncChoicePath, $script:SyncChoiceLockPath, $script:SyncCatalogPath, $script:SyncChoiceWaitMs = $syncSaved
  $script:McpPerPc = $false
}
