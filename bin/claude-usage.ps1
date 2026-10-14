. (Join-Path $PSScriptRoot "claude-usage-cache.ps1")
. (Join-Path $PSScriptRoot "claude-usage-pace.ps1")
. (Join-Path $PSScriptRoot "claude-accounts.ps1")
. (Join-Path $PSScriptRoot "claude-token-refresh.ps1")

function Get-PlanName {
  param($Oauth)
  if ($Oauth.rateLimitTier -match "max_(\d+)x") { return "Max " + $Matches[1] + "x" }
  $t = "" + $Oauth.subscriptionType
  if ($t -eq "") { return "" }
  return $t.Substring(0, 1).ToUpper() + $t.Substring(1)
}

function Get-RetryAfter {
  param($Response)
  try {
    if ($null -ne $Response.Headers.RetryAfter) { return [int]$Response.Headers.RetryAfter.Delta.TotalSeconds }
    return [int]$Response.Headers["Retry-After"]
  } catch { return 0 }
}

function Get-UsageToken {
  param($Acc, $Cred)
  if ($null -eq $Cred -or [string]::IsNullOrEmpty($Cred.claudeAiOauth.accessToken)) { return @{ Error = "non connecte" } }
  $expMs = [long]$Cred.claudeAiOauth.expiresAt
  if ($expMs -le 0 -or $expMs -ge [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()) { return @{ Token = $Cred.claudeAiOauth.accessToken } }
  $fresh = Update-AccountToken $Acc $Cred
  if ($null -eq $fresh) { return @{ Error = "compte deconnecte, lancer le compte une fois" } }
  return @{ Token = $fresh.claudeAiOauth.accessToken }
}

function Get-UsageErrorText {
  param($Response)
  $code = 0
  if ($null -ne $Response) { $code = [int]$Response.StatusCode }
  if ($code -eq 401) { return "jeton refuse, lancer le compte une fois" }
  return "API de suivi injoignable"
}

function Set-UsageLimited {
  param($Out, $Entry, [int]$Seconds)
  if ($null -ne $Entry -and [long]$Entry.At -gt 0) {
    Copy-CacheEntry $Entry $Out
    $Out.LimitedUntil = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() + $Seconds
    return
  }
  $Out.Error = "quota inconnu, l'API de suivi refuse les appels (reessai dans " + (Format-Age $Seconds) + ")"
}

function Register-UsageRefusal {
  param($Out, $Entry, $Response)
  $fails = 1 + [int]$Entry.Fails
  $wait = Get-CooldownSeconds $fails (Get-RetryAfter $Response) (Get-Random -Maximum ($fails * 5 + 1))
  Save-UsageCooldown $Out.Label $wait $fails
  Set-UsageLimited $Out $Entry $wait
}

function Get-AccountUsage {
  param($Acc, [int]$MaxAge = $script:UsageCacheTtl)
  $out = [PSCustomObject]@{Label=$Acc.Label; Email=(Get-AccountEmail $Acc); Acc=$Acc; Plan=""; Pct5=$null; Reset5=$null; Pct7=$null; Reset7=$null; Error=$null; Age=$null; Expired=$false; LimitedUntil=$null}
  $cred = Read-AccountCredential $Acc
  if ($null -ne $cred) { $out.Plan = Get-PlanName $cred.claudeAiOauth }
  $cached = (Read-UsageCache)[$Acc.Label]
  if ($null -ne $cached -and (Get-CacheAge $cached) -lt $MaxAge) { Copy-CacheEntry $cached $out; return $out }
  $left = Get-CooldownLeft $cached
  if ($left -gt 0) { Set-UsageLimited $out $cached $left; return $out }
  try {
    $tok = Get-UsageToken $Acc $cred
    if ($tok.Error) { $out.Error = $tok.Error; return $out }
    $h = @{"Authorization"="Bearer " + $tok.Token; "anthropic-beta"="oauth-2025-04-20"; "Accept"="application/json"}
    $ProgressPreference = "SilentlyContinue"
    $r = Invoke-RestMethod -Uri "https://api.anthropic.com/api/oauth/usage" -Headers $h -TimeoutSec 10
    if ($null -ne $r.five_hour) { $out.Pct5 = [math]::Round([double]$r.five_hour.utilization); $out.Reset5 = $r.five_hour.resets_at }
    if ($null -ne $r.seven_day) { $out.Pct7 = [math]::Round([double]$r.seven_day.utilization); $out.Reset7 = $r.seven_day.resets_at }
    Save-UsageEntry $Acc.Label $out
  } catch {
    $resp = $_.Exception.Response
    if ($null -ne $resp -and [int]$resp.StatusCode -eq 429) { Register-UsageRefusal $out $cached $resp; return $out }
    $out.Error = Get-UsageErrorText $resp
  }
  return $out
}

function Format-Reset {
  param($Iso)
  $at = ConvertTo-DateOffset $Iso
  if ($null -eq $at) { return "-" }
  $dt = $at.LocalDateTime
  $now = Get-Date
  $span = $dt - $now
  $hhmm = $dt.ToString("HH:mm")
  if ($span.TotalSeconds -le 0) { return "$hhmm (passe)" }
  $h = [math]::Floor($span.TotalHours)
  $m = $span.Minutes
  $mm = "{0:D2}" -f $m
  if ($h -ge 24) {
    $d = [math]::Floor($h / 24)
    return $dt.ToString("dd/MM HH:mm") + " (dans " + $d + "j" + ($h % 24) + "h)"
  }
  return "$hhmm (dans " + $h + "h" + $mm + ")"
}

function Format-Row {
  param($U)
  $line = $U.Label + " " + $U.Email + " " + $U.Plan + " | "
  if ($null -ne $U.Error) { return $line + $U.Error }
  $line = $line + "5h " + $U.Pct5 + "% reset " + (Format-Reset $U.Reset5) + (Format-PaceSuffix "5h" $U.Pct5 $U.Reset5)
  $line = $line + " | 7d " + $U.Pct7 + "% reset " + (Format-Reset $U.Reset7) + (Format-PaceSuffix "7d" $U.Pct7 $U.Reset7)
  return $line + (Format-Stale $U)
}

function Format-PaceSuffix {
  param([string]$Kind, $Pct, $Reset)
  $p = Get-UsagePace $Kind $Pct $Reset
  if ($null -eq $p) { return "" }
  return ", " + $p.Text
}

function Format-Stale {
  param($U)
  if ($U.Expired) { return " (fenetre passee, lu il y a " + (Format-Age $U.Age) + ")" }
  if ($null -eq $U.Age -or $U.Age -lt 60) { return "" }
  return " (lu il y a " + (Format-Age $U.Age) + ")"
}

function Get-AllUsages {
  return @(Get-Accounts | ForEach-Object { Get-AccountUsage $_ })
}
