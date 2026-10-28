function Save-SealedMedia {
  param([string]$Id, [string]$Path, [string]$Seal, $Keys)
  if ($null -eq $Keys -or -not $Seal.StartsWith("files/")) { throw "cle ou chemin scelle absent" }
  if ($Id.StartsWith("panne")) { throw "panne reseau" }
  if ($Id.StartsWith("lent")) { Start-Sleep -Seconds 20 }
  [IO.File]::WriteAllText($Path, "pre-" + $Id)
}

function Send-SealedFile {
  param([string]$FolderId, [string]$Rel, [byte[]]$Bytes, $Props, [string]$Id, $Keys)
  if ($null -eq $Keys) { throw "cle absente" }
  return @{ Id = "up-" + $Rel + "-" + $Bytes.Length + "-" + $Props["pc"]; Md5 = "" }
}

function Get-SyncBytes {
  param([string]$Rel, [string]$Path)
  return ,[IO.File]::ReadAllBytes($Path)
}

function Remove-DriveTemp {
  param([string]$Tmp)
  if ([IO.File]::Exists($Tmp)) { [IO.File]::Delete($Tmp) }
}
