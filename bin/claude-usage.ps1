. (Join-Path $PSScriptRoot "claude-usage-cache.ps1")
. (Join-Path $PSScriptRoot "claude-usage-pace.ps1")
. (Join-Path $PSScriptRoot "claude-accounts.ps1")

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
    if ($Response.Headers.RetryAfter -ne $null) { return [int]$Response.Headers.RetryAfter.Delta.TotalSeconds }
    return $Response.Headers["Retry-After"]
  } catch { return $null }
}

function Get-CompteUsage {
  param($Acc)
  $Label = $Acc.Label
  $out = [PSCustomObject]@{Label=$Label; Email=(Get-AccountEmail $Acc); Acc=$Acc; Plan=""; Pct5=$null; Reset5=$null; Pct7=$null; Reset7=$null; Error=$null; Age=$null; Expired=$false}
  $cred = Read-AccountCredential $Acc
  if ($cred -ne $null) { $out.Plan = Get-PlanName $cred.claudeAiOauth }
  $cached = (Read-UsageCache)[$Label]
  if ($cached -ne $null -and (Get-CacheAge $cached) -lt $script:UsageCacheTtl) { Copy-CacheEntry $cached $out; return $out }
  try {
    if ($cred -eq $null) { $out.Error = "non connecte"; return $out }
    $tok = $cred.claudeAiOauth.accessToken
    if ([string]::IsNullOrEmpty($tok)) { $out.Error = "non connecte"; return $out }
    $expMs = [long]$cred.claudeAiOauth.expiresAt
    if ($expMs -gt 0 -and $expMs -lt [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()) {
      if ($cached -ne $null) { Copy-CacheEntry $cached $out } else { $out.Error = "jeton a rafraichir, lancer le compte une fois" }
      return $out
    }
    $h = @{"Authorization"="Bearer $tok"; "anthropic-beta"="oauth-2025-04-20"; "Accept"="application/json"}
    $ProgressPreference = "SilentlyContinue"
    $r = Invoke-RestMethod -Uri "https://api.anthropic.com/api/oauth/usage" -Headers $h -TimeoutSec 10
    if ($r.five_hour -ne $null) {
      $out.Pct5 = [math]::Round([double]$r.five_hour.utilization)
      $out.Reset5 = $r.five_hour.resets_at
    }
    if ($r.seven_day -ne $null) {
      $out.Pct7 = [math]::Round([double]$r.seven_day.utilization)
      $out.Reset7 = $r.seven_day.resets_at
    }
    Save-UsageEntry $Label $out
  } catch {
    $code = 0
    if ($_.Exception.Response -ne $null) { $code = [int]$_.Exception.Response.StatusCode }
    if ($code -eq 429 -and $cached -ne $null) { Copy-CacheEntry $cached $out; return $out }
    if ($code -eq 429) {
      $wait = Get-RetryAfter $_.Exception.Response
      $out.Error = "quota inconnu, l'API de suivi refuse les appels"
      if ($wait) { $out.Error = $out.Error + " (reessai dans " + (Format-Age ([int]$wait)) + ")" }
    }
    elseif ($code -eq 401) { $out.Error = "jeton refuse, lancer le compte une fois" }
    else { $out.Error = "API de suivi injoignable" }
  }
  return $out
}

function Format-Reset {
  param($Iso)
  $at = ConvertTo-DateOffset $Iso
  if ($at -eq $null) { return "-" }
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
  if ($U.Error -ne $null) { return $line + $U.Error }
  $line = $line + "5h " + $U.Pct5 + "% reset " + (Format-Reset $U.Reset5) + (Format-PaceSuffix "5h" $U.Pct5 $U.Reset5)
  $line = $line + " | 7d " + $U.Pct7 + "% reset " + (Format-Reset $U.Reset7) + (Format-PaceSuffix "7d" $U.Pct7 $U.Reset7)
  return $line + (Format-Stale $U)
}

function Format-PaceSuffix {
  param([string]$Kind, $Pct, $Reset)
  $p = Get-UsagePace $Kind $Pct $Reset
  if ($p -eq $null) { return "" }
  return ", " + $p.Text
}

function Format-Stale {
  param($U)
  if ($U.Expired) { return " (perime, lu il y a " + (Format-Age $U.Age) + ")" }
  if ($U.Age -eq $null -or $U.Age -lt 60) { return "" }
  return " (lu il y a " + (Format-Age $U.Age) + ")"
}

function Get-AllUsages {
  return @(Get-Accounts | ForEach-Object { Get-CompteUsage $_ })
}
