if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-drive-creds.ps1")) { . (Join-Path $PSScriptRoot "claude-drive-creds.ps1") }
$script:OauthTokenUrl = "https://platform.claude.com/v1/oauth/token"
$script:OauthClientId = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"

function ConvertTo-RefreshedCredential {
  param($Cred, $Resp, [long]$NowMs)
  $o = $Cred.claudeAiOauth
  $o.accessToken = "" + $Resp.access_token
  if (-not [string]::IsNullOrEmpty($Resp.refresh_token)) { $o.refreshToken = "" + $Resp.refresh_token }
  $o.expiresAt = $NowMs + [long]$Resp.expires_in * 1000
  return $Cred
}

function Get-OauthUserAgent {
  return "claude-cli/" + (Get-ClaudeVersion) + " (external, cli)"
}

function Save-RefreshedCredential {
  param($Acc, $Cred)
  $credFile = Join-Path (Get-AccountPath $Acc) ".credentials.json"
  Invoke-WithFileLock $script:CredLockPath $script:CredLockWaitMs "jetons en cours de synchro" { Write-CredentialFile $credFile $Cred }
}

function Update-AccountToken {
  param($Acc, $Cred)
  if ($script:OsName -eq "MacOS") { return $null }
  $fresh = Receive-DriveCredential $Acc
  if ($null -ne $fresh) {
    if (Test-CredentialUsable $fresh) { return $fresh }
    $Cred = $fresh
  }
  if (Test-AccountAway $Acc) { return $null }
  $rt = "" + $Cred.claudeAiOauth.refreshToken
  if ($rt -eq "") { return $null }
  $body = @{ grant_type = "refresh_token"; refresh_token = $rt; client_id = $script:OauthClientId }
  $scopes = @($Cred.claudeAiOauth.scopes) -join " "
  if ($scopes -ne "") { $body.scope = $scopes }
  $ProgressPreference = "SilentlyContinue"
  try {
    $r = Invoke-RestMethod -Method Post -Uri $script:OauthTokenUrl -Body ($body | ConvertTo-Json -Compress) -ContentType "application/json" -Headers @{ "User-Agent" = (Get-OauthUserAgent) } -TimeoutSec 15
  } catch { return $null }
  if ([string]::IsNullOrEmpty($r.access_token) -or $null -eq $r.expires_in) { return $null }
  $new = ConvertTo-RefreshedCredential $Cred $r ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
  try { Save-RefreshedCredential $Acc $new } catch { return $null }
  Send-DriveCredential $Acc
  return $new
}
