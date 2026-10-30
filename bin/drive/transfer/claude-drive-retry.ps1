$script:DriveRetryMax = 5
$script:DriveRetryBaseMs = 500
$script:DriveRetryCapMs = 30000
$script:DriveRetryAfterMaxMs = 60000
$script:DriveErrorBodyMax = 400
$script:DriveRateReasons = '"reason"\s*:\s*"(rateLimitExceeded|userRateLimitExceeded)"'
$script:DriveRetrySleep = { param([int]$Ms) Start-Sleep -Milliseconds $Ms }
$script:DriveRetryJitter = { param([int]$Ms) return Get-Random -Minimum 0 -Maximum ([int]($Ms / 2) + 1) }

function Get-HttpStatus {
  param($ErrorRecord)
  try { return [int]$ErrorRecord.Exception.Response.StatusCode } catch { return 0 }
}

function Get-DriveErrorBody {
  param($ErrorRecord)
  $text = ""
  try { $text = [string]$ErrorRecord.ErrorDetails.Message } catch { Write-Verbose $_.Exception.Message }
  if ($text) { return $text }
  try {
    $stream = $ErrorRecord.Exception.Response.GetResponseStream()
    if ($null -ne $stream) { $reader = New-Object IO.StreamReader($stream); try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() } }
  } catch { Write-Verbose $_.Exception.Message }
  return $text
}

function Get-RetryAfterMs {
  param($ErrorRecord)
  $response = $null
  try { $response = $ErrorRecord.Exception.Response } catch { return 0 }
  if ($null -eq $response) { return 0 }
  $raw = ""
  try { $raw = [string]$response.Headers["Retry-After"] } catch { Write-Verbose $_.Exception.Message }
  if (-not $raw) {
    try {
      $header = $response.Headers.RetryAfter
      if ($null -ne $header -and $null -ne $header.Delta) { $raw = [string][int]$header.Delta.TotalSeconds }
      elseif ($null -ne $header -and $null -ne $header.Date) { $raw = $header.Date.ToString("r") }
    } catch { Write-Verbose $_.Exception.Message }
  }
  $seconds = 0
  if ([int]::TryParse($raw.Trim(), [ref]$seconds)) { return [Math]::Max(0, $seconds) * 1000 }
  $when = [DateTimeOffset]::MinValue
  if ([DateTimeOffset]::TryParse($raw, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$when)) {
    return [int][Math]::Max(0, ($when - [DateTimeOffset]::UtcNow).TotalMilliseconds)
  }
  return 0
}

function Test-DriveRetryable {
  param($ErrorRecord, [string]$Body)
  $status = Get-HttpStatus $ErrorRecord
  if ($status -eq 429 -or $status -eq 500 -or ($status -ge 502 -and $status -le 504)) { return $true }
  return $status -eq 403 -and $Body -match $script:DriveRateReasons
}

function Get-DriveRetryDelayMs {
  param([int]$Attempt, [int]$RetryAfterMs)
  $backoff = [int][Math]::Min([double]$script:DriveRetryCapMs, [double]$script:DriveRetryBaseMs * [Math]::Pow(2, $Attempt))
  $wait = $backoff
  if ($backoff -lt $script:DriveRetryCapMs) { $wait = $backoff + [int](& $script:DriveRetryJitter $backoff) }
  return [Math]::Max($wait, $RetryAfterMs)
}

function New-DriveFailure {
  param($ErrorRecord, [string]$Body)
  $detail = ($Body -replace "\s+", " ").Trim()
  if ($detail.Length -gt $script:DriveErrorBodyMax) { $detail = $detail.Substring(0, $script:DriveErrorBodyMax) }
  $message = $ErrorRecord.Exception.Message
  if ($detail) { $message = $message + " : " + $detail }
  $failure = New-Object Exception($message, $ErrorRecord.Exception)
  $failure.Data["HttpStatus"] = Get-HttpStatus $ErrorRecord
  return $failure
}
