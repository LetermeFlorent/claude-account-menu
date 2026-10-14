. (Join-Path $PSScriptRoot "claude-drive-config.ps1")
$script:DriveAuthUrl = "https://accounts.google.com/o/oauth2/v2/auth"
$script:DriveTokenUrl = "https://oauth2.googleapis.com/token"
$script:DriveScope = "https://www.googleapis.com/auth/drive.file"
$script:DriveReconnect = "reconnecter le Drive : clm --drive-login"
$script:DriveClientId = "841970424266-pgppljvgm4sunmm9fhhggemhk976vm05.apps.googleusercontent.com"
$script:DriveClientSecret = "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"

function Get-DriveClient {
  param($Config)
  if ($null -ne $Config -and $Config["clientId"] -and $Config["clientSecret"]) { return @{ Id = [string]$Config["clientId"]; Secret = [string]$Config["clientSecret"] } }
  return @{ Id = $script:DriveClientId; Secret = $script:DriveClientSecret }
}

function ConvertTo-Base64Url {
  param([byte[]]$Bytes)
  return [Convert]::ToBase64String($Bytes).TrimEnd("=").Replace("+", "-").Replace("/", "_")
}

function Get-Sha256Bytes {
  param([string]$Text)
  $sha = [Security.Cryptography.SHA256]::Create()
  try { return $sha.ComputeHash([Text.Encoding]::ASCII.GetBytes($Text)) } finally { $sha.Dispose() }
}

function New-PkcePair {
  $bytes = New-Object byte[] 32
  $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
  try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
  $verifier = ConvertTo-Base64Url $bytes
  return @{ Verifier = $verifier; Challenge = (ConvertTo-Base64Url (Get-Sha256Bytes $verifier)) }
}

function ConvertTo-FormText {
  param($Pairs)
  return (@($Pairs.Keys | ForEach-Object { $_ + "=" + [Uri]::EscapeDataString([string]$Pairs[$_]) }) -join "&")
}

function Get-DriveAuthUrl {
  param([string]$ClientId, [string]$Redirect, [string]$Challenge, [string]$State)
  $q = [ordered]@{
    client_id = $ClientId; redirect_uri = $Redirect; response_type = "code"; scope = $script:DriveScope
    access_type = "offline"; prompt = "consent"; code_challenge = $Challenge; code_challenge_method = "S256"; state = $State
  }
  return $script:DriveAuthUrl + "?" + (ConvertTo-FormText $q)
}

function Invoke-DriveTokenPost {
  param([string]$Body)
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  $ProgressPreference = "SilentlyContinue"
  return Invoke-RestMethod -Method Post -Uri $script:DriveTokenUrl -Body $Body -ContentType "application/x-www-form-urlencoded" -TimeoutSec 15
}

function Request-DriveToken {
  param($Config, $Form)
  $client = Get-DriveClient $Config
  $all = [ordered]@{ client_id = $client.Id; client_secret = $client.Secret }
  foreach ($k in $Form.Keys) { $all[$k] = $Form[$k] }
  try { return Invoke-DriveTokenPost (ConvertTo-FormText $all) }
  catch {
    $detail = "" + $_.ErrorDetails.Message + " " + $_.Exception.Message
    if ($detail -match "invalid_grant|invalid_client|unauthorized_client") { throw $script:DriveReconnect }
    throw ("jeton Google refuse : " + $_.Exception.Message)
  }
}

function Set-DriveTokenResponse {
  param($Config, $Resp, [long]$NowMs)
  $Config["accessToken"] = [string]$Resp.access_token
  $Config["expiresAt"] = $NowMs + [long]$Resp.expires_in * 1000
  if (-not [string]::IsNullOrEmpty([string]$Resp.refresh_token)) { $Config["refreshToken"] = [string]$Resp.refresh_token }
}

function Get-DriveToken {
  param([switch]$Renew)
  $c = Read-DriveConfig
  if ($null -eq $c -or [string]::IsNullOrEmpty([string]$c["refreshToken"])) { throw $script:DriveReconnect }
  $now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  if (-not $Renew -and $c["accessToken"] -and [long]$c["expiresAt"] -gt $now + 60000) { return [string]$c["accessToken"] }
  $r = Request-DriveToken $c @{ grant_type = "refresh_token"; refresh_token = [string]$c["refreshToken"] }
  Set-DriveTokenResponse $c $r $now
  Save-DriveConfig $c
  return [string]$c["accessToken"]
}
