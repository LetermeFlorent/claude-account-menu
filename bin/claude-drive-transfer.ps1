. Import-ClmModule claude-drive-api, claude-sync-crypto, claude-drive-transfer-chunks
$script:SealRequired = "telechargement refuse sans cle de synchro"

function New-MultipartBody {
  param([string]$MetaJson, [byte[]]$Bytes, [string]$Boundary)
  $head = "--" + $Boundary + "`r`nContent-Type: " + $script:DriveJsonType + "`r`n`r`n" + $MetaJson + "`r`n--" + $Boundary + "`r`nContent-Type: application/octet-stream`r`n`r`n"
  $ms = New-Object IO.MemoryStream
  foreach ($part in @([Text.Encoding]::UTF8.GetBytes($head), $Bytes, [Text.Encoding]::UTF8.GetBytes("`r`n--" + $Boundary + "--"))) { $ms.Write($part, 0, $part.Length) }
  return ,$ms.ToArray()
}

function Get-DriveMeta {
  param([string]$FolderId, [string]$Name, $Props, [string]$Id)
  $meta = [ordered]@{}
  if (-not $Id) { $meta.name = $Name; $meta.parents = @($FolderId) }
  $meta.appProperties = $Props
  return ConvertTo-JsonText $meta
}

function Send-DriveBytes {
  param([string]$MetaJson, [byte[]]$Bytes, [string]$Id)
  $boundary = "clm" + [guid]::NewGuid().ToString("N")
  $t = Get-UploadTarget $Id "multipart"
  $body = New-MultipartBody $MetaJson $Bytes $boundary
  return ConvertTo-UploadResult (Invoke-DriveRequest $t.Method $t.Uri $body ("multipart/related; boundary=" + $boundary) $script:DriveDataTimeout)
}

function Read-ByteSource {
  param($Source, [byte[]]$Buffer, [int]$Offset, [int]$Count)
  $n = [int][Math]::Min($Count, $Source.Bytes.Length - $Source.At)
  if ($n -gt 0) { [Array]::Copy($Source.Bytes, $Source.At, $Buffer, $Offset, $n) }
  $Source.At += $n
  return $n
}

function Send-DriveResumable {
  param([string]$MetaJson, [byte[]]$Bytes, [string]$Id)
  $source = @{ Length = [long]$Bytes.Length; Read = "Read-ByteSource"; Bytes = $Bytes; At = 0 }
  return Send-DriveChunks $MetaJson $source $Id
}

function Read-SharedBytes {
  param([string]$Path)
  $fs = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
  try {
    $ms = New-Object IO.MemoryStream
    $fs.CopyTo($ms)
    return ,$ms.ToArray()
  } finally { $fs.Dispose() }
}

function Send-DriveContent {
  param([string]$FolderId, [string]$Name, [byte[]]$Bytes, $Props, [string]$Id)
  $meta = Get-DriveMeta $FolderId $Name $Props $Id
  if ($Bytes.Length -le $script:DriveSimpleMax) { return Send-DriveBytes $meta $Bytes $Id }
  return Send-DriveResumable $meta $Bytes $Id
}

function Send-DriveText {
  param([string]$FolderId, [string]$Name, [string]$Text, $Props, [string]$Id)
  return Send-DriveContent $FolderId $Name ([Text.Encoding]::UTF8.GetBytes($Text)) $Props $Id
}

function Get-DriveBytes {
  param([string]$Id)
  $r = Invoke-DriveRequest "GET" ($script:DriveApi + "/" + $Id + "?alt=media") $null "" $script:DriveDataTimeout
  if ($null -eq $r -or $null -eq $r.RawContentStream) { return ,(New-Object byte[] 0) }
  return ,$r.RawContentStream.ToArray()
}

function Save-SealedMedia {
  param([string]$Id, [string]$Path, [string]$Seal, $Keys)
  if ($null -eq $Keys) { throw $script:SealRequired }
  [IO.File]::WriteAllBytes($Path, (Unprotect-SyncBytes $Keys $Seal (Get-DriveBytes $Id)))
}

function Receive-DriveTemp {
  param([string]$Id, [string]$Path, [string]$Seal, $Keys)
  $null = [IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
  $tmp = $Path + "." + [guid]::NewGuid().ToString("N") + ".tmp"
  try { Save-SealedMedia $Id $tmp $Seal $Keys } catch { Remove-DriveTemp $tmp; throw }
  return $tmp
}

function Remove-DriveTemp {
  param([string]$Tmp)
  if ([IO.File]::Exists($Tmp)) { Remove-Item -LiteralPath $Tmp -Force -ErrorAction SilentlyContinue }
}

function Install-DriveTemp {
  param([string]$Tmp, [string]$Path, [switch]$InPlace)
  if (-not [IO.File]::Exists($Path)) { [IO.File]::Move($Tmp, $Path); return }
  if (-not $InPlace) { [IO.File]::Replace($Tmp, $Path, [NullString]::Value); return }
  $src = [IO.File]::OpenRead($Tmp)
  try {
    $dst = [IO.File]::Open($Path, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::Read)
    try { $src.CopyTo($dst) } finally { $dst.Dispose() }
  } finally { $src.Dispose() }
}

function Receive-DriveFile {
  param([string]$Id, [string]$Path, [string]$Seal, $Keys)
  $tmp = Receive-DriveTemp $Id $Path $Seal $Keys
  try { Install-DriveTemp $tmp $Path } finally { Remove-DriveTemp $tmp }
}
