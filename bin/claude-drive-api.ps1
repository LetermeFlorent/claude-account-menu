. (Join-Path $PSScriptRoot "claude-drive-auth.ps1")
$script:DriveApi = "https://www.googleapis.com/drive/v3/files"
$script:DriveUpload = "https://www.googleapis.com/upload/drive/v3/files"
$script:DriveFolderMime = "application/vnd.google-apps.folder"
$script:DriveSimpleMax = 5MB
$script:DriveMetaTimeout = 15
$script:DriveDataTimeout = 120
$script:DriveJsonType = "application/json; charset=UTF-8"
$script:DriveFolderNames = @{ Root = "clm-sync"; Files = "files"; Credentials = "credentials"; Presence = "presence" }

function Invoke-DriveWeb {
  param($Request)
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  $ProgressPreference = "SilentlyContinue"
  return Invoke-WebRequest @Request
}

function Get-HttpStatus {
  param($ErrorRecord)
  try { return [int]$ErrorRecord.Exception.Response.StatusCode } catch { return 0 }
}

function Invoke-DriveRequest {
  param([string]$Method, [string]$Uri, $Body = $null, [string]$ContentType = "", [int]$Timeout = 15, [string]$OutFile = "", $Headers = $null)
  $renew = $false
  while ($true) {
    $h = @{ Authorization = "Bearer " + (Get-DriveToken -Renew:$renew) }
    if ($null -ne $Headers) { foreach ($k in $Headers.Keys) { $h[$k] = $Headers[$k] } }
    $req = @{ Method = $Method; Uri = $Uri; Headers = $h; TimeoutSec = $Timeout; UseBasicParsing = $true }
    if ($null -ne $Body) { $req.Body = $Body }
    if ($ContentType) { $req.ContentType = $ContentType }
    if ($OutFile) { $req.OutFile = $OutFile; $req.PassThru = $true }
    try { return Invoke-DriveWeb $req }
    catch {
      if ($renew -or (Get-HttpStatus $_) -ne 401) { throw }
      $renew = $true
    }
  }
}

function Get-ResponseText {
  param($Response)
  if ($null -eq $Response -or $null -eq $Response.RawContentStream) { return "" }
  return [Text.Encoding]::UTF8.GetString($Response.RawContentStream.ToArray())
}

function ConvertFrom-DriveJson {
  param($Response)
  $t = Get-ResponseText $Response
  if ($t.Trim() -eq "") { return $null }
  return $t | ConvertFrom-Json
}

function ConvertTo-JsonBytes {
  param($Value)
  return [Text.Encoding]::UTF8.GetBytes((ConvertTo-JsonText $Value))
}

function ConvertTo-DriveQuery {
  param([string]$Text)
  return $Text.Replace("\", "\\").Replace("'", "\'")
}

function New-MultipartBody {
  param([string]$MetaJson, [byte[]]$Bytes, [string]$Boundary)
  $head = "--" + $Boundary + "`r`nContent-Type: " + $script:DriveJsonType + "`r`n`r`n" + $MetaJson + "`r`n--" + $Boundary + "`r`nContent-Type: application/octet-stream`r`n`r`n"
  $ms = New-Object IO.MemoryStream
  foreach ($part in @([Text.Encoding]::UTF8.GetBytes($head), $Bytes, [Text.Encoding]::UTF8.GetBytes("`r`n--" + $Boundary + "--"))) { $ms.Write($part, 0, $part.Length) }
  return ,$ms.ToArray()
}

function Find-DriveFolder {
  param([string]$Name, [string]$Parent)
  $q = "name='" + (ConvertTo-DriveQuery $Name) + "' and mimeType='" + $script:DriveFolderMime + "' and trashed=false and '" + (ConvertTo-DriveQuery $Parent) + "' in parents"
  $uri = $script:DriveApi + "?q=" + [Uri]::EscapeDataString($q) + "&orderBy=createdTime&pageSize=10&fields=files(id)"
  $r = ConvertFrom-DriveJson (Invoke-DriveRequest "GET" $uri)
  if (@($r.files).Count -gt 0) { return [string]@($r.files)[0].id }
  $meta = [ordered]@{ name = $Name; mimeType = $script:DriveFolderMime; parents = @($Parent) }
  $r = ConvertFrom-DriveJson (Invoke-DriveRequest "POST" ($script:DriveApi + "?fields=id") (ConvertTo-JsonBytes $meta) $script:DriveJsonType)
  return [string]$r.id
}

function Get-DriveFolders {
  $c = Read-DriveConfig
  $keys = @("Root", "Files", "Credentials", "Presence")
  $out = @{}
  foreach ($k in $keys) { $out[$k] = [string]$c[("folder" + $k)] }
  if (@($keys | Where-Object { -not $out[$_] }).Count -eq 0) { return $out }
  $out.Root = Find-DriveFolder $script:DriveFolderNames.Root "root"
  foreach ($k in @("Files", "Credentials", "Presence")) { $out[$k] = Find-DriveFolder $script:DriveFolderNames[$k] $out.Root }
  $c = Read-DriveConfig
  foreach ($k in $keys) { $c[("folder" + $k)] = $out[$k] }
  Save-DriveConfig $c
  return $out
}

function Clear-DriveFolders {
  $c = Read-DriveConfig
  if ($null -eq $c) { return }
  foreach ($k in @("Root", "Files", "Credentials", "Presence")) { $c.Remove(("folder" + $k)) }
  Save-DriveConfig $c
}

function ConvertTo-RemoteEntry {
  param($File)
  $props = @{}
  if ($null -ne $File.appProperties) { foreach ($p in $File.appProperties.PSObject.Properties) { $props[$p.Name] = [string]$p.Value } }
  return @{ Id = [string]$File.id; Name = [string]$File.name; Md5 = [string]$File.md5Checksum; M = [long]$props["m"]; Pc = [string]$props["pc"]; Exp = [long]$props["exp"]; Props = $props }
}

function Get-DriveListing {
  param([string]$FolderId)
  $map = New-PathMap
  $dups = New-Object 'System.Collections.Generic.List[string]'
  $q = [Uri]::EscapeDataString("'" + (ConvertTo-DriveQuery $FolderId) + "' in parents and trashed=false")
  $fields = [Uri]::EscapeDataString("nextPageToken,files(id,name,md5Checksum,appProperties)")
  $token = ""
  do {
    $uri = $script:DriveApi + "?q=" + $q + "&pageSize=1000&fields=" + $fields
    if ($token) { $uri += "&pageToken=" + [Uri]::EscapeDataString($token) }
    $r = ConvertFrom-DriveJson (Invoke-DriveRequest "GET" $uri)
    foreach ($f in @($r.files)) {
      if ($null -eq $f) { continue }
      $e = ConvertTo-RemoteEntry $f
      $old = $map[$e.Name]
      if ($null -eq $old) { $map[$e.Name] = $e }
      elseif ($e.M -gt $old.M) { $map[$e.Name] = $e; $dups.Add($old.Id) }
      else { $dups.Add($e.Id) }
    }
    $token = [string]$r.nextPageToken
  } while ($token)
  foreach ($id in $dups) { try { Remove-DriveFile $id } catch {} }
  return $map
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

function Set-DriveFileMeta {
  param([string]$Id, $Meta)
  $null = Invoke-DriveRequest "PATCH" ($script:DriveApi + "/" + $Id) (ConvertTo-JsonBytes $Meta) $script:DriveJsonType $script:DriveMetaTimeout
}

function Remove-DriveFile {
  param([string]$Id)
  Set-DriveFileMeta $Id ([ordered]@{ trashed = $true })
}

function Set-DriveProps {
  param([string]$Id, $Props)
  Set-DriveFileMeta $Id ([ordered]@{ appProperties = $Props })
}
