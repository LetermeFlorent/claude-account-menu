. Import-ClmModule claude-drive-transfer-chunks
class ChunkHttpFailure : Exception {
  $Response
  ChunkHttpFailure([string]$Message, $Response) : base($Message) { $this.Response = $Response }
}
. (Join-Path $bin "drive/core/claude-drive-api.ps1"); $script:ChunkToken = ${function:Get-DriveToken}
$script:ChunkSaved = @{ Size = $script:DriveChunkSize; Max = $script:DriveChunkRetryMax; Sleep = $script:DriveRetrySleep; Jitter = $script:DriveRetryJitter }
$script:DriveChunkSize = 256KB
function New-ChunkTestSource {
  param([int]$Size)
  $pattern = New-Object byte[] 251
  foreach ($i in 0..250) { $pattern[$i] = [byte](($i * 7 + 3) % 251) }
  $bytes = New-Object byte[] $Size
  for ($at = 0; $at -lt $Size; $at += 251) { [Array]::Copy($pattern, 0, $bytes, $at, [Math]::Min(251, $Size - $at)) }
  return @{ Length = [long]$Size; Read = "Read-ChunkTestSource"; Bytes = $bytes; At = 0 }
}
function Read-ChunkTestSource {
  param($Source, [byte[]]$Buffer, [int]$Offset, [int]$Count)
  $n = [Math]::Min($Count, $Source.Bytes.Length - $Source.At)
  if ($n -gt 0) { [Array]::Copy($Source.Bytes, $Source.At, $Buffer, $Offset, $n) }
  $Source.At += $n
  return [int]$n
}
function New-ChunkFailure {
  param([int]$Status, $Headers = @{})
  $response = [PSCustomObject]@{ StatusCode = $Status; Headers = $Headers }
  return @{ Failure = [ChunkHttpFailure]::new("Le serveur distant a retourne une erreur : (" + $Status + ")", $response) }
}
function New-ChunkMore {
  param($Last)
  if ($null -eq $Last) { return New-ChunkFailure 308 }
  return New-ChunkFailure 308 @{ Range = "bytes=0-" + $Last }
}
function New-ChunkResponse {
  param([string]$Json, $Headers = @{})
  $stream = New-Object IO.MemoryStream(, [Text.Encoding]::UTF8.GetBytes($Json))
  return [PSCustomObject]@{ StatusCode = 200; RawContentStream = $stream; Headers = $Headers }
}
function New-ChunkDone { return New-ChunkResponse '{"id":"F1","md5Checksum":"m1"}' }
$script:ChunkQueue = New-Object 'System.Collections.Generic.Queue[object]'
$script:ChunkCalls = New-Object 'System.Collections.Generic.List[object]'
$script:ChunkSlept = New-Object 'System.Collections.Generic.List[int]'
$script:ChunkRenews = New-Object 'System.Collections.Generic.List[bool]'
$script:ChunkMaxBody = 0
function Get-DriveToken { param([switch]$Renew) $script:ChunkRenews.Add([bool]$Renew); return "tok" }
function Invoke-DriveWeb {
  param($Request)
  $body = $Request.Body
  $length = 0
  if ($body -is [byte[]]) { $length = $body.Length; $body = [byte[]]$body.Clone() }
  if ($Request.Method -eq "PUT" -and $length -gt $script:ChunkMaxBody) { $script:ChunkMaxBody = $length }
  $script:ChunkCalls.Add([PSCustomObject]@{ Method = $Request.Method; Uri = $Request.Uri; Headers = $Request.Headers.Clone(); Range = $Request.Headers["Content-Range"]; Length = $length; Body = $body })
  if ($Request.Method -ne "PUT") { return New-ChunkResponse "" @{ Location = "https://upload.example/s1" } }
  $item = $script:ChunkQueue.Dequeue()
  if ($item -is [hashtable]) { throw $item.Failure }
  return $item
}
function Start-ChkCase {
  param([int]$Size, [object[]]$Answers, [string]$Id = "")
  $script:ChunkQueue.Clear()
  $script:ChunkCalls.Clear()
  $script:ChunkSlept.Clear()
  $script:ChunkRenews.Clear()
  $script:DriveRetrySleep = { param([int]$Ms) $script:ChunkSlept.Add($Ms) }
  $script:DriveRetryJitter = { param([int]$Ms) return 0 }
  foreach ($answer in $Answers) { $script:ChunkQueue.Enqueue($answer) }
  $script:ChunkSource = New-ChunkTestSource $Size
  $script:ChunkFailed = ""
  $script:ChunkResult = $null
  try { $script:ChunkResult = Send-DriveChunks '{"name":"a"}' $script:ChunkSource $Id } catch { $script:ChunkFailed = "!" + $_.Exception.Message }
}
function Get-ChkPuts { return @($script:ChunkCalls | Where-Object { $_.Method -eq "PUT" }) }
function Get-ChkHash {
  param([byte[]]$Bytes)
  return [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($Bytes))
}
function Get-ChkSliceHash {
  param([int]$From, [int]$To)
  $slice = New-Object byte[] ($To - $From + 1)
  [Array]::Copy($script:ChunkSource.Bytes, $From, $slice, 0, $slice.Length)
  return Get-ChkHash $slice
}
function Get-ChkJoinedHash {
  $out = New-Object byte[] $script:ChunkSource.Bytes.Length
  foreach ($put in (Get-ChkPuts)) {
    if ($put.Range -match '^bytes (\d+)-(\d+)/') { [Array]::Copy($put.Body, 0, $out, [int]$Matches[1], $put.Body.Length) }
  }
  return Get-ChkHash $out
}
$script:ChunkClose = {
  $script:DriveChunkSize = $script:ChunkSaved.Size; $script:DriveChunkRetryMax = $script:ChunkSaved.Max
  $script:DriveRetrySleep = $script:ChunkSaved.Sleep; $script:DriveRetryJitter = $script:ChunkSaved.Jitter
  . (Join-Path $bin "drive/core/claude-drive-api.ps1"); if ($script:ChunkToken) { Set-Item Function:\Get-DriveToken $script:ChunkToken } else { Remove-Item Function:\Get-DriveToken }
  Remove-Item Function:\*-Chk*, Function:\New-ChunkTestSource, Function:\Read-ChunkTestSource, Function:\New-ChunkFailure, Function:\New-ChunkMore, Function:\New-ChunkResponse, Function:\New-ChunkDone
  Remove-Variable ChunkToken, ChunkSaved, ChunkQueue, ChunkCalls, ChunkSlept, ChunkRenews, ChunkMaxBody, ChunkSource, ChunkFailed, ChunkResult, ChunkClose -Scope Script -ErrorAction SilentlyContinue
  Remove-Variable chunkPuts, chunkStart, chunkStatus -ErrorAction SilentlyContinue
}
