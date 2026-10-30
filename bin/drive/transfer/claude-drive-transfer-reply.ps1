. Import-ClmModule claude-drive-api
$script:DriveChunkResume = 308

function Get-DriveReplyHeader {
  param($Response, [string]$Name)
  if ($null -eq $Response -or $null -eq $Response.Headers) { return "" }
  $value = ""
  try { $value = [string]@($Response.Headers[$Name])[0] } catch { Write-Verbose $_.Exception.Message }
  if ($value) { return $value }
  $values = $null
  try { if ($Response.Headers.TryGetValues($Name, [ref]$values)) { $value = [string]@($values)[0] } } catch { Write-Verbose $_.Exception.Message }
  return $value
}

function Get-ReceivedEnd {
  param([string]$Range)
  if ($Range -match '^bytes=0-(\d+)$') { return [long]$Matches[1] + 1 }
  return [long]0
}

function New-ChunkReply {
  param([int]$Status, $Response)
  return @{ Status = $Status; Response = $Response; Next = (Get-ReceivedEnd (Get-DriveReplyHeader $Response "Range")); Failure = $null }
}

function Get-ReplyStatus {
  param($Response)
  if ($null -ne $Response -and $Response.StatusCode) { return [int]$Response.StatusCode }
  return 200
}

function Invoke-DriveChunkWeb {
  param([string]$Uri, [byte[]]$Body, [string]$Range, [int]$Timeout)
  $renew = $false
  while ($true) {
    $headers = @{ Authorization = "Bearer " + (Get-DriveToken -Renew:$renew); "Content-Range" = $Range }
    $req = @{ Method = "PUT"; Uri = $Uri; Headers = $headers; Body = $Body; ContentType = "application/octet-stream"; TimeoutSec = $Timeout; UseBasicParsing = $true }
    try {
      $r = Invoke-DriveWeb $req
      return New-ChunkReply (Get-ReplyStatus $r) $r
    } catch {
      $status = Get-HttpStatus $_
      if ($status -eq 401 -and -not $renew) { $renew = $true; continue }
      if ($status -eq $script:DriveChunkResume) { return New-ChunkReply $status $_.Exception.Response }
      return @{ Status = $status; Response = $null; Next = [long]0; Failure = $_ }
    }
  }
}

function Assert-ChunkRetry {
  param($Failure, [int]$Failures)
  $status = Get-HttpStatus $Failure
  $body = Get-DriveErrorBody $Failure
  $retry = $status -eq 0 -or $status -eq 408 -or (Test-DriveRetryable $Failure $body)
  if (-not $retry -or $Failures -ge $script:DriveChunkRetryMax -or (Get-RetryAfterMs $Failure) -gt $script:DriveRetryAfterMaxMs) { throw (New-DriveFailure $Failure $body) }
}
