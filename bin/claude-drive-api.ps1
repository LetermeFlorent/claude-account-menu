. Import-ClmModule claude-drive-auth, claude-drive-retry
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

function Invoke-DriveRequest {
  param($Request)
  $timeout = 15
  if ($null -ne $Request.Timeout) { $timeout = [int]$Request.Timeout }
  $renew = $false
  $attempt = 0
  while ($true) {
    $h = @{ Authorization = "Bearer " + (Get-DriveToken -Renew:$renew) }
    if ($null -ne $Request.Headers) { foreach ($k in $Request.Headers.Keys) { $h[$k] = $Request.Headers[$k] } }
    $req = @{ Method = $Request.Method; Uri = $Request.Uri; Headers = $h; TimeoutSec = $timeout; UseBasicParsing = $true }
    if ($null -ne $Request.Body) { $req.Body = $Request.Body }
    if ($Request.ContentType) { $req.ContentType = $Request.ContentType }
    if ($Request.OutFile) { $req.OutFile = $Request.OutFile }
    try { return Invoke-DriveWeb $req }
    catch {
      $failure = $_
      if (-not $renew -and (Get-HttpStatus $failure) -eq 401) { $renew = $true; continue }
      $body = Get-DriveErrorBody $failure
      $waitMs = Get-RetryAfterMs $failure
      if ($attempt -ge $script:DriveRetryMax -or $waitMs -gt $script:DriveRetryAfterMaxMs -or -not (Test-DriveRetryable $failure $body)) { throw (New-DriveFailure $failure $body) }
      & $script:DriveRetrySleep (Get-DriveRetryDelayMs $attempt $waitMs)
      $attempt++
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
  return ,[Text.Encoding]::UTF8.GetBytes((ConvertTo-JsonText $Value))
}

function ConvertTo-DriveQuery {
  param([string]$Text)
  return $Text.Replace("\", "\\").Replace("'", "\'")
}

function New-RemoteEntry {
  param([string]$Id, [string]$Name, [string]$Md5, $Props)
  return @{ Id = $Id; Name = $Name; Md5 = $Md5; M = [long]$Props["m"]; Pc = [string]$Props["pc"]; Exp = [long]$Props["exp"]; Props = $Props }
}

function ConvertTo-RemoteEntry {
  param($File)
  $props = @{}
  if ($null -ne $File.appProperties) { foreach ($p in $File.appProperties.PSObject.Properties) { $props[$p.Name] = [string]$p.Value } }
  $md5 = [string]$File.md5Checksum
  if ($props["h"]) { $md5 = $props["h"] }
  return New-RemoteEntry ([string]$File.id) ([string]$File.name) $md5 $props
}

function Get-RemoteIds {
  param($Entry)
  $ids = [string[]]@(@($Entry.SealedId, $Entry.PlainId) | Where-Object { $_ })
  if ($ids.Count -eq 0 -and $Entry.Id) { $ids = [string[]]@($Entry.Id) }
  return ,$ids
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
    try { $r = ConvertFrom-DriveJson (Invoke-DriveRequest @{ Method = "GET"; Uri = $uri }) }
    catch { if ($_.Exception.Data["HttpStatus"] -eq 404) { $_.Exception.Data["FolderGone"] = $true }; throw }
    foreach ($f in @($r.files)) {
      if ($null -eq $f) { continue }
      $e = ConvertTo-RemoteEntry $f
      $old = $map[$e.Name]
      if ($null -eq $old) { $map[$e.Name] = $e }
      elseif ($e.M -gt $old.M -or $e.Exp -gt $old.Exp) { $map[$e.Name] = $e; $dups.Add($old.Id) }
      else { $dups.Add($e.Id) }
    }
    $token = [string]$r.nextPageToken
  } while ($token)
  foreach ($id in $dups) { try { Remove-DriveFile $id } catch { Write-Verbose $_.Exception.Message } }
  return $map
}

function Set-DriveFileMeta {
  param([string]$Id, $Meta)
  $null = Invoke-DriveRequest @{ Method = "PATCH"; Uri = ($script:DriveApi + "/" + $Id); Body = (ConvertTo-JsonBytes $Meta); ContentType = $script:DriveJsonType; Timeout = $script:DriveMetaTimeout }
}

function Remove-DriveFile {
  param([string]$Id)
  Set-DriveFileMeta $Id ([ordered]@{ trashed = $true })
}

function Set-DriveProps {
  param([string]$Id, $Props)
  Set-DriveFileMeta $Id ([ordered]@{ appProperties = $Props })
}
