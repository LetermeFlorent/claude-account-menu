if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-drive-auth.ps1")) { . (Join-Path $PSScriptRoot "claude-drive-auth.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-drive-retry.ps1")) { . (Join-Path $PSScriptRoot "claude-drive-retry.ps1") }
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
  param([string]$Method, [string]$Uri, $Body = $null, [string]$ContentType = "", [int]$Timeout = 15, [string]$OutFile = "", $Headers = $null)
  $renew = $false
  $attempt = 0
  while ($true) {
    $h = @{ Authorization = "Bearer " + (Get-DriveToken -Renew:$renew) }
    if ($null -ne $Headers) { foreach ($k in $Headers.Keys) { $h[$k] = $Headers[$k] } }
    $req = @{ Method = $Method; Uri = $Uri; Headers = $h; TimeoutSec = $Timeout; UseBasicParsing = $true }
    if ($null -ne $Body) { $req.Body = $Body }
    if ($ContentType) { $req.ContentType = $ContentType }
    if ($OutFile) { $req.OutFile = $OutFile; $req.PassThru = $true }
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
  return New-RemoteEntry ([string]$File.id) ([string]$File.name) ([string]$File.md5Checksum) $props
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
