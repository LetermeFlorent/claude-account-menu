. Import-ClmModule claude-drive-files, claude-drive-sealed, claude-drive-transfer, claude-drive-transfer-chunks, claude-drive-transfer-seal

function Send-SealedPath {
  param($Item)
  $rel = [string]$Item.Rel
  $path = [string]$Item.Path
  $id = [string]$Item.Id
  $md5 = Get-FileMd5 $path
  $meta = Get-DriveMeta ([string]$Item.FolderId) ($script:SealedPrefix + $rel) (New-SealedProps $Item.Keys $md5 $Item.Props) $id
  $source = Open-SealedSource $Item.Keys ($script:SealedFilesArea + $rel) $path
  try { $r = Send-DriveChunks $meta $source $id } finally { Close-SealedSource $source }
  return @{ Id = $r.Id; Md5 = $md5 }
}

function Test-StreamedUpload {
  param([string]$Rel, [string]$Path)
  if (Test-MachineSettingsPath $Rel) { return $false }
  $info = [IO.FileInfo]$Path
  return $info.Exists -and $info.Length -gt $script:DriveSimpleMax
}

function Send-LocalFile {
  param($Item)
  if (Test-StreamedUpload ([string]$Item.Rel) ([string]$Item.Path)) { return Send-SealedPath $Item }
  $bytes = Get-SyncBytes ([string]$Item.Rel) ([string]$Item.Path)
  return Send-SealedFile @{ FolderId = $Item.FolderId; Rel = $Item.Rel; Bytes = $bytes; Props = $Item.Props; Id = $Item.Id; Keys = $Item.Keys }
}
