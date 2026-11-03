. Import-ClmModule claude-credentials, claude-accounts
$script:PlanCache = @{}
$script:ApiPlanCache = @{}
$script:ProfileApiUrl = "https://api.anthropic.com/api/oauth/profile"

function Invoke-ProfileApi {
  param([string]$Token)
  $h = @{ "Authorization" = "Bearer " + $Token; "anthropic-beta" = "oauth-2025-04-20"; "Accept" = "application/json" }
  $ProgressPreference = "SilentlyContinue"
  return Invoke-RestMethod -Uri $script:ProfileApiUrl -Headers $h -TimeoutSec 10
}

function Get-ApiPlanName {
  param($Acc, [string]$Token)
  $key = Get-AccountPath $Acc
  $stamp = Get-CredentialStamp $Acc
  $hit = $script:ApiPlanCache[$key]
  if ($null -ne $hit -and $hit.Stamp -ceq $stamp) { return $hit.Plan }
  $plan = ""
  try { $plan = ("" + (Invoke-ProfileApi $Token).organization.plan_display_name).Trim() } catch { $plan = "" }
  $script:ApiPlanCache[$key] = @{ Stamp = $stamp; Plan = $plan }
  return $plan
}

function Get-PlanName {
  param($Oauth)
  if ($Oauth.rateLimitTier -match "max_(\d+)x") { return "Max " + $Matches[1] + "x" }
  $t = "" + $Oauth.subscriptionType
  if ($t -eq "") { return "" }
  return $t.Substring(0, 1).ToUpper() + $t.Substring(1)
}

function Get-CredentialStamp {
  param($Acc)
  if ($script:OsName -eq "MacOS") { return "keychain" }
  try {
    $info = New-Object IO.FileInfo (Join-Path (Get-AccountPath $Acc) ".credentials.json")
    if (-not $info.Exists) { return "none" }
    return "" + $info.LastWriteTimeUtc.Ticks + ":" + $info.Length
  } catch { return "none" }
}

function Get-CachedPlan {
  param($Acc)
  $key = Get-AccountPath $Acc
  $stamp = Get-CredentialStamp $Acc
  $hit = $script:PlanCache[$key]
  if ($null -ne $hit -and $hit.Stamp -ceq $stamp) { return $hit.Plan }
  $cred = Read-AccountCredential $Acc
  $plan = ""
  if ($null -ne $cred) { $plan = Get-PlanName $cred.claudeAiOauth }
  $script:PlanCache[$key] = @{ Stamp = $stamp; Plan = $plan }
  return $plan
}
