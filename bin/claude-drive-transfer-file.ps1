. Import-ClmModule claude-drive-files, claude-drive-sealed, claude-drive-transfer, claude-drive-transfer-chunks, claude-drive-transfer-seal

function Send-SealedPath {
  param([string]$FolderId, [string]$Rel, [string]$Path, $Props, [string]$Id, $Keys)
  $md5 = Get-FileMd5 $Path
  $meta = Get-DriveMeta $FolderId ($script:SealedPrefix + $Rel) (New-SealedProps $Keys $md5 $Props) $Id
  $source = Open-SealedSource $Keys ($script:SealedFilesArea + $Rel) $Path
  try { $r = Send-DriveChunks $meta $source $Id } finally { Close-SealedSource $source }
  return @{ Id = $r.Id; Md5 = $md5 }
}

function Test-StreamedUpload {
  param([string]$Rel, [string]$Path)
  if (Test-MachineSettingsPath $Rel) { return $false }
  $info = [IO.FileInfo]$Path
  return $info.Exists -and $info.Length -gt $script:DriveSimpleMax
}

function Send-LocalFile {
  param([string]$FolderId, [string]$Rel, [string]$Path, $Props, [string]$Id, $Keys)
  if (Test-StreamedUpload $Rel $Path) { return Send-SealedPath $FolderId $Rel $Path $Props $Id $Keys }
  return Send-SealedFile $FolderId $Rel (Get-SyncBytes $Rel $Path) $Props $Id $Keys
}
