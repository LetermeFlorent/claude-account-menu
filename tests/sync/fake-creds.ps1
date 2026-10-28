$script:CredTestKeys = New-SyncKeys ([byte[]](60..91)) ([byte[]](1..16)) 600000
Save-SyncKeys $script:CredTestKeys

function Get-CredTestBytes {
  return ,(Protect-SyncBytes $script:CredTestKeys ("credentials/" + $acc.Dir + ".json") ([Text.Encoding]::UTF8.GetBytes($script:RemoteText)))
}

function Get-DriveBytes { param([string]$Id) return ,(Get-CredTestBytes) }

function Send-DriveContent {
  param([string]$FolderId, [string]$Name, [byte[]]$Bytes, $Props, [string]$Id)
  $plain = $Bytes
  if ($FolderId -eq "C") { $plain = Unprotect-SyncBytes $script:CredTestKeys ("credentials/" + $Name) $Bytes }
  $text = [Text.Encoding]::UTF8.GetString($plain)
  $script:Sent.Add(@{ Folder = $FolderId; Name = $Name; Text = $text; Props = $Props; Id = $Id; Bytes = $Bytes })
  return @{ Id = "n"; Md5 = "" }
}
