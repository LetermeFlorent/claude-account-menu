. (Join-Path $PSScriptRoot "drive-race-store.ps1")

function Get-DriveFolders { return @{ Root = "R"; Files = "F"; Credentials = "C"; Presence = "P" } }
function Sync-DriveCredentials { param($Folders, $Accs, $Keys) return 0 }

function Get-DriveListing {
  param([string]$FolderId)
  $map = New-PathMap
  foreach ($e in (Read-DriveRaceEntries $script:DriveRaceStore $FolderId)) { if ($null -eq $map[$e.Name]) { $map[$e.Name] = $e } }
  return $map
}

function Get-DriveFilesListing { param($Folders, [string]$Pc) return Get-DriveListing $Folders.Files }

function Send-DriveContent {
  param([string]$FolderId, [string]$Name, [byte[]]$Bytes, $Props, [string]$Id)
  $all = @{}
  $path = $null
  if ($Id) { $path = Find-DriveRaceFile $script:DriveRaceStore $Id }
  if ($Id -and -not $path) { throw ("fichier Drive introuvable : " + $Id) }
  if ($path) {
    $old = Read-DriveRaceEntry $path
    $FolderId = $old.Folder
    foreach ($k in $old.Props.Keys) { $all[$k] = $old.Props[$k] }
  } else { $Id = "id" + [guid]::NewGuid().ToString("N") }
  if ($null -ne $Props) { foreach ($k in $Props.Keys) { $all[$k] = [string]$Props[$k] } }
  return Write-DriveRaceEntry $script:DriveRaceStore $FolderId $Id $Name $all $Bytes
}

function Get-DriveBytes {
  param([string]$Id)
  $path = Find-DriveRaceFile $script:DriveRaceStore $Id
  if (-not $path) { throw ("fichier Drive introuvable : " + $Id) }
  return ,(Read-DriveRaceEntry $path).Bytes
}

function Remove-DriveFile {
  param([string]$Id)
  $path = Find-DriveRaceFile $script:DriveRaceStore $Id
  if ($path) { [IO.File]::Delete($path) }
}

function Remove-DriveFiles {
  param([string[]]$Ids, $Ctl, [long]$DeadlineMs)
  if (Test-SyncStop $Ctl $DeadlineMs) { return 0 }
  foreach ($id in $Ids) { Remove-DriveFile $id }
  return $Ids.Count
}

function Set-DriveProps {
  param([string]$Id, $Props)
  $path = Find-DriveRaceFile $script:DriveRaceStore $Id
  if (-not $path) { throw ("fichier Drive introuvable : " + $Id) }
  $old = Read-DriveRaceEntry $path
  foreach ($k in $Props.Keys) { $old.Props[$k] = [string]$Props[$k] }
  $null = Write-DriveRaceEntry $script:DriveRaceStore $old.Folder $Id $old.Name $old.Props $old.Bytes
}
