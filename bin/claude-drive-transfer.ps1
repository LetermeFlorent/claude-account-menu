. (Join-Path $PSScriptRoot "claude-drive-api.ps1")

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

function ConvertTo-UploadResult {
  param($Response)
  $r = ConvertFrom-DriveJson $Response
  return @{ Id = [string]$r.id; Md5 = [string]$r.md5Checksum }
}

function Get-UploadTarget {
  param([string]$Id, [string]$Type)
  $uri = $script:DriveUpload
  $method = "POST"
  if ($Id) { $uri += "/" + $Id; $method = "PATCH" }
  return @{ Method = $method; Uri = $uri + "?uploadType=" + $Type + "&fields=id,md5Checksum" }
}

function Send-DriveBytes {
  param([string]$MetaJson, [byte[]]$Bytes, [string]$Id)
  $boundary = "clm" + [guid]::NewGuid().ToString("N")
  $t = Get-UploadTarget $Id "multipart"
  $body = New-MultipartBody $MetaJson $Bytes $boundary
  return ConvertTo-UploadResult (Invoke-DriveRequest $t.Method $t.Uri $body ("multipart/related; boundary=" + $boundary) $script:DriveDataTimeout)
}

function Send-DriveResumable {
  param([string]$MetaJson, [byte[]]$Bytes, [string]$Id)
  $t = Get-UploadTarget $Id "resumable"
  $r = Invoke-DriveRequest $t.Method $t.Uri ([Text.Encoding]::UTF8.GetBytes($MetaJson)) $script:DriveJsonType $script:DriveMetaTimeout "" @{ "X-Upload-Content-Length" = ("" + $Bytes.Length) }
  $session = [string]@($r.Headers["Location"])[0]
  if (-not $session) { throw "Drive : session d'envoi refusee" }
  $timeout = $script:DriveDataTimeout + [int]($Bytes.Length / 100KB)
  return ConvertTo-UploadResult (Invoke-DriveRequest "PUT" $session $Bytes "application/octet-stream" $timeout)
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

function Send-DriveFile {
  param([string]$FolderId, [string]$Name, [string]$Path, $Props, [string]$Id)
  return Send-DriveContent $FolderId $Name (Read-SharedBytes $Path) $Props $Id
}

function Send-DriveText {
  param([string]$FolderId, [string]$Name, [string]$Text, $Props, [string]$Id)
  return Send-DriveContent $FolderId $Name ([Text.Encoding]::UTF8.GetBytes($Text)) $Props $Id
}

function Receive-DriveFile {
  param([string]$Id, [string]$Path)
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $tmp = $Path + "." + [guid]::NewGuid().ToString("N") + ".tmp"
  try {
    $null = Invoke-DriveRequest "GET" ($script:DriveApi + "/" + $Id + "?alt=media") $null "" $script:DriveDataTimeout $tmp
    if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($tmp, $Path, [NullString]::Value) }
    else { [IO.File]::Move($tmp, $Path) }
  } finally { if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue } }
}

function Get-DriveText {
  param([string]$Id)
  return Get-ResponseText (Invoke-DriveRequest "GET" ($script:DriveApi + "/" + $Id + "?alt=media") $null "" $script:DriveDataTimeout)
}
