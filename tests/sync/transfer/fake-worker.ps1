function Save-DriveMedia {
  param([string]$Id, [string]$Path)
  if ($Id.StartsWith("panne")) { throw "panne reseau" }
  if ($Id.StartsWith("lent")) { Start-Sleep -Seconds 20 }
  [IO.File]::WriteAllText($Path, "pre-" + $Id)
}

function Send-DriveContent {
  param([string]$FolderId, [string]$Name, [byte[]]$Bytes, $Props, [string]$Id)
  return @{ Id = "up-" + $Name + "-" + $Bytes.Length + "-" + $Props["pc"]; Md5 = "" }
}

function Get-SyncBytes {
  param([string]$Rel, [string]$Path)
  return ,[IO.File]::ReadAllBytes($Path)
}

function Remove-DriveTemp {
  param([string]$Tmp)
  if ([IO.File]::Exists($Tmp)) { [IO.File]::Delete($Tmp) }
}
