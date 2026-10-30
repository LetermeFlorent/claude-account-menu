if (-not (Test-Path Function:\Import-ClmModule)) { . (Join-Path $PSScriptRoot "../claude-import.ps1") }
. Import-ClmModule claude-usage-cache, claude-usage-poll, claude-usage-pace, claude-accounts, claude-token-refresh, claude-usage-bar, claude-machine-lock, claude-usage-format, claude-usage-plan, claude-text
$script:UsageApiUrl = "https://api.anthropic.com/api/oauth/usage"
$script:UsageApiTimeoutSec = 10
$script:UsageLockWaitMs = 15000
$script:UsageTokenMarginMs = 60000

function Get-RetryAfter {
  param($Response)
  try {
    if ($null -ne $Response.Headers.RetryAfter) { return [int]$Response.Headers.RetryAfter.Delta.TotalSeconds }
    return [int]$Response.Headers["Retry-After"]
  } catch { return 0 }
}

function Get-UsageToken {
  param($Acc, $Cred, [switch]$NoRefresh)
  if ($null -eq $Cred -or [string]::IsNullOrEmpty($Cred.claudeAiOauth.accessToken)) { return @{ Error = Get-ClmText "ui.usage.notSignedIn" } }
  $expMs = [long]$Cred.claudeAiOauth.expiresAt
  $nowMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  if ($expMs -le 0 -or $expMs -ge $nowMs + $script:UsageTokenMarginMs) { return @{ Token = $Cred.claudeAiOauth.accessToken } }
  if ($NoRefresh) {
    if ($expMs -ge $nowMs) { return @{ Token = $Cred.claudeAiOauth.accessToken } }
    return @{ Error = Get-ClmText "ui.usage.tokenExpired" }
  }
  $fresh = Update-AccountToken $Acc $Cred
  if ($null -eq $fresh) { return @{ Error = Get-ClmText "ui.usage.signedOut" } }
  return @{ Token = $fresh.claudeAiOauth.accessToken }
}

function Get-UsageErrorText {
  param($Response)
  $code = 0
  if ($null -ne $Response) { $code = [int]$Response.StatusCode }
  if ($code -eq 401) { return Get-ClmText "ui.usage.tokenRefused" }
  return Get-ClmText "ui.usage.unreachable"
}

function Set-UsageLimited {
  param($Out, $Entry, [int]$Seconds)
  if ($null -ne $Entry -and [long]$Entry.At -gt 0) {
    Copy-CacheEntry $Entry $Out
    $Out.LimitedUntil = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() + $Seconds
    return
  }
  $Out.Error = Get-ClmText "ui.usage.limited" (Format-Age $Seconds)
}

function Register-UsageRefusal {
  param($Out, $Entry, $Response)
  $fails = 1 + [int]$Entry.Fails
  $wait = Get-CooldownSeconds $fails (Get-RetryAfter $Response) (Get-Random -Maximum ($fails * 5 + 1))
  Save-UsageCooldown $Out.Label $wait $fails
  Set-UsageLimited $Out $Entry $wait
}

function Invoke-UsageApi {
  param([string]$Token)
  $h = @{ "Authorization" = "Bearer " + $Token; "anthropic-beta" = "oauth-2025-04-20"; "Accept" = "application/json" }
  $ProgressPreference = "SilentlyContinue"
  return Invoke-RestMethod -Uri $script:UsageApiUrl -Headers $h -TimeoutSec $script:UsageApiTimeoutSec
}

function Get-UsageLockName {
  param($Acc)
  return "usage-" + (Get-StateTag (Get-AccountPath $Acc))
}

function Test-UsageSettled {
  param($Out, $Known, [int]$MaxAge)
  if ($null -ne $Known -and (Get-CacheAge $Known) -lt $MaxAge) { Copy-CacheEntry $Known $Out; return $true }
  $left = Get-CooldownLeft $Known
  if ($left -le 0) { return $false }
  Set-UsageLimited $Out $Known $left
  return $true
}

function Set-UsageBusy {
  param($Out, $Known)
  if ($null -ne $Known -and [long]$Known.At -gt 0) { Copy-CacheEntry $Known $Out; return }
  $Out.Error = Get-ClmText "ui.usage.busy"
}

function Request-AccountUsage {
  param($Out, $Acc, $Cred, $Known, [switch]$NoRefresh)
  try {
    $tok = Get-UsageToken $Acc $Cred -NoRefresh:$NoRefresh
    if ($tok.Error) { $Out.Error = $tok.Error; return }
    $r = Invoke-UsageApi $tok.Token
    if ($null -ne $r.five_hour) { $Out.Pct5 = [math]::Round([double]$r.five_hour.utilization); $Out.Reset5 = $r.five_hour.resets_at }
    if ($null -ne $r.seven_day) { $Out.Pct7 = [math]::Round([double]$r.seven_day.utilization); $Out.Reset7 = $r.seven_day.resets_at }
    $Out.At = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    Save-UsageEntry $Acc.Label $Out $Out.At
  } catch {
    $resp = $_.Exception.Response
    if ($null -ne $resp -and [int]$resp.StatusCode -eq 429) { Register-UsageRefusal $Out $Known $resp; return }
    $Out.Error = Get-UsageErrorText $resp
  }
}

function Get-AccountUsage {
  param($Acc, [int]$MaxAge = (Read-UsagePollSeconds), [switch]$NoRefresh)
  $out = New-UsageRow $Acc
  $out.Plan = Get-CachedPlan $Acc
  $known = Get-KnownUsage $Acc (Read-UsageCache)
  if (Test-UsageSettled $out $known $MaxAge) { return $out }
  $lock = Open-MachineLock (Get-UsageLockName $Acc) $script:UsageLockWaitMs
  if ($null -eq $lock) { Set-UsageBusy $out $known; return $out }
  try {
    try { $known = Get-KnownUsage $Acc (Read-UsageCacheMap) } catch { Set-UsageBusy $out $known; return $out }
    if (-not (Test-UsageSettled $out $known $MaxAge)) { Request-AccountUsage $out $Acc (Read-AccountCredential $Acc) $known -NoRefresh:$NoRefresh }
  } finally { Close-MachineLock $lock }
  return $out
}

function Get-FreshUsage {
  param($Acc)
  return Get-AccountUsage $Acc $script:ForcedReadMaxAge
}

function Get-AllUsages {
  return @(Get-Accounts | ForEach-Object { Get-AccountUsage $_ })
}
