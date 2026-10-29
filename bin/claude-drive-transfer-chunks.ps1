. Import-ClmModule claude-drive-api, claude-drive-transfer-reply
$script:DriveChunkSize = 8MB
$script:DriveChunkRetryMax = 5

function Get-UploadTarget {
  param([string]$Id, [string]$Type)
  $uri = $script:DriveUpload
  $method = "POST"
  if ($Id) { $uri += "/" + $Id; $method = "PATCH" }
  return @{ Method = $method; Uri = $uri + "?uploadType=" + $Type + "&fields=id,md5Checksum" }
}

function ConvertTo-UploadResult {
  param($Response)
  $r = ConvertFrom-DriveJson $Response
  return @{ Id = [string]$r.id; Md5 = [string]$r.md5Checksum }
}

function Open-UploadSession {
  param([string]$MetaJson, [long]$Length, [string]$Id)
  $t = Get-UploadTarget $Id "resumable"
  $r = Invoke-DriveRequest $t.Method $t.Uri ([Text.Encoding]::UTF8.GetBytes($MetaJson)) $script:DriveJsonType $script:DriveMetaTimeout "" @{ "X-Upload-Content-Length" = ("" + $Length) }
  $session = [string]@($r.Headers["Location"])[0]
  if (-not $session) { throw "Drive : session d'envoi refusee" }
  return $session
}

function Get-ChunkRange {
  param([long]$Start, [int]$Count, [long]$Total)
  if ($Count -eq 0) { return "bytes */" + $Total }
  return "bytes " + $Start + "-" + ($Start + $Count - 1) + "/" + $Total
}

function Read-ChunkWindow {
  param($Window, $Source)
  while ($Window.Count -lt $Window.Buffer.Length) {
    $n = [int](& $Source.Read $Source $Window.Buffer $Window.Count ($Window.Buffer.Length - $Window.Count))
    if ($n -le 0) { break }
    $Window.Count += $n
  }
  if ($Window.Count -eq 0 -and $Window.Start -lt $Source.Length) { throw "Drive : fichier plus court que prevu pendant l'envoi" }
}

function Get-ChunkBody {
  param($Window)
  if ($Window.Count -eq $Window.Buffer.Length) { return ,$Window.Buffer }
  $body = New-Object byte[] $Window.Count
  [Array]::Copy($Window.Buffer, $body, $Window.Count)
  return ,$body
}

function Move-ChunkWindow {
  param($Window, [long]$Next)
  $end = $Window.Start + $Window.Count
  if ($Next -lt $Window.Start -or $Next -gt $end) { throw ("Drive : position d'envoi incoherente " + $Next) }
  $keep = [int]($end - $Next)
  [Array]::Copy($Window.Buffer, [int]($Next - $Window.Start), $Window.Buffer, 0, $keep)
  $Window.Count = $keep
  $Window.Start = $Next
}

function Resume-DriveSession {
  param([string]$Session, [long]$Total, $Reply, $Window)
  while ($Reply.Failure) {
    Assert-ChunkRetry $Reply.Failure $Window.Failures
    & $script:DriveRetrySleep (Get-DriveRetryDelayMs $Window.Failures (Get-RetryAfterMs $Reply.Failure))
    $Window.Failures++
    $Reply = Invoke-DriveChunkWeb $Session (New-Object byte[] 0) (Get-ChunkRange 0 0 $Total) $script:DriveMetaTimeout
  }
  return $Reply
}

function Wait-ChunkStall {
  param($Window)
  if ($Window.Failures -ge $script:DriveChunkRetryMax) { throw "Drive : l'envoi n'avance plus" }
  & $script:DriveRetrySleep (Get-DriveRetryDelayMs $Window.Failures 0)
  $Window.Failures++
}

function Send-ChunkWindow {
  param([string]$Session, $Window, [long]$Total)
  $body = Get-ChunkBody $Window
  $timeout = $script:DriveDataTimeout + [int]($body.Length / 100KB)
  $reply = Invoke-DriveChunkWeb $Session $body (Get-ChunkRange $Window.Start $Window.Count $Total) $timeout
  $Window.Resumed = $null -ne $reply.Failure
  if ($Window.Resumed) { $reply = Resume-DriveSession $Session $Total $reply $Window }
  return $reply
}

function Send-DriveChunks {
  param([string]$MetaJson, $Source, [string]$Id)
  $total = [long]$Source.Length
  $session = Open-UploadSession $MetaJson $total $Id
  $window = @{ Buffer = (New-Object byte[] ([int][Math]::Min([long]$script:DriveChunkSize, $total))); Count = 0; Start = [long]0; Failures = 0; Resumed = $false }
  while ($true) {
    Read-ChunkWindow $window $Source
    $reply = Send-ChunkWindow $session $window $total
    if ($reply.Status -ge 200 -and $reply.Status -lt 300) { return ConvertTo-UploadResult $reply.Response }
    if ($reply.Status -ne $script:DriveChunkResume) { throw ("Drive : reponse d'envoi inattendue " + $reply.Status) }
    $before = $window.Start
    Move-ChunkWindow $window $reply.Next
    if ($window.Start -gt $before) { $window.Failures = 0 } elseif (-not $window.Resumed) { Wait-ChunkStall $window }
  }
}
