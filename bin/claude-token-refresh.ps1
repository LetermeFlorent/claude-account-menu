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

function Write-CredentialFile {
  param([string]$Path, $Cred)
  $tmp = $Path + "." + [guid]::NewGuid().ToString("N") + ".tmp"
  $json = $Cred | ConvertTo-Json -Depth 10 -Compress
  [IO.File]::WriteAllText($tmp, $json, (New-Object Text.UTF8Encoding($false)))
  if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($tmp, $Path, [NullString]::Value) }
  else { [IO.File]::Move($tmp, $Path) }
}

function Update-AccountToken {
  param($Acc, $Cred)
  if ($script:OsName -eq "MacOS") { return $null }
  $rt = "" + $Cred.claudeAiOauth.refreshToken
  if ($rt -eq "") { return $null }
  $body = @{ grant_type = "refresh_token"; refresh_token = $rt; client_id = $script:OauthClientId }
  $scopes = @($Cred.claudeAiOauth.scopes) -join " "
  if ($scopes -ne "") { $body.scope = $scopes }
  $ProgressPreference = "SilentlyContinue"
  try {
    $r = Invoke-RestMethod -Method Post -Uri $script:OauthTokenUrl -Body ($body | ConvertTo-Json -Compress) -ContentType "application/json" -TimeoutSec 15
  } catch { return $null }
  if ([string]::IsNullOrEmpty($r.access_token) -or $r.expires_in -eq $null) { return $null }
  $new = ConvertTo-RefreshedCredential $Cred $r ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
  try { Write-CredentialFile (Join-Path (Get-AccountPath $Acc) ".credentials.json") $new } catch { return $null }
  return $new
}
