if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-drive-transfer.ps1")) { . (Join-Path $PSScriptRoot "claude-drive-transfer.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-drive-folders.ps1")) { . (Join-Path $PSScriptRoot "claude-drive-folders.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-drive-presence.ps1")) { . (Join-Path $PSScriptRoot "claude-drive-presence.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-state.ps1")) { . (Join-Path $PSScriptRoot "claude-state.ps1") }
$script:CredentialMarginMs = 60000
$script:CredLockPath = Get-StatePath "drive-creds.lock"
$script:CredLockWaitMs = 15000
$script:CredentialUnknownOwner = "adresse locale inconnue, jeton du Drive refuse"
$script:CredentialNoOwner = "jeton du Drive sans adresse, refuse"
$script:CredentialTooFar = "jeton du Drive refuse : expiration trop lointaine"
$script:CredentialMaxAheadMs = [long]30 * 24 * 3600 * 1000

function Get-CredentialExpiry {
  param($Cred)
  if ($null -eq $Cred -or $null -eq $Cred.claudeAiOauth) { return [long]0 }
  return [long]$Cred.claudeAiOauth.expiresAt
}

function Select-FresherCredential {
  param([long]$LocalExp, [long]$RemoteExp)
  if ($RemoteExp -gt $LocalExp) { return "remote" }
  if ($LocalExp -gt $RemoteExp) { return "local" }
  return "same"
}

function Get-CredentialName {
  param($Acc)
  return $Acc.Dir + ".json"
}

function Read-LocalCredential {
  param($Acc)
  if ($script:OsName -eq "MacOS") { return Read-AccountCredential $Acc }
  $p = Join-Path (Get-AccountPath $Acc) ".credentials.json"
  if (-not (Test-Path -LiteralPath $p)) { return $null }
  try { $raw = [IO.File]::ReadAllText($p) } catch { throw "jeton local illisible" }
  try { return $raw | ConvertFrom-Json } catch { return $null }
}

function Assert-CredentialOwner {
  param($Acc, $Remote)
  if ($null -eq $Remote -or $null -eq $Remote.Props) { return }
  $who = [string]$Remote.Props["who"]
  $mine = Get-AccountEmail $Acc
  if ($who -and -not $mine) { throw $script:CredentialUnknownOwner }
  if ($who -and $who -ne $mine) { throw ("jeton du Drive pour une autre adresse (" + $who + ")") }
}

function Assert-RemoteCredentialTrusted {
  param($Acc, $Remote)
  $who = ""
  if ($null -ne $Remote.Props) { $who = [string]$Remote.Props["who"] }
  if (-not $who) { throw $script:CredentialNoOwner }
  if (-not (Get-AccountEmail $Acc)) { throw $script:CredentialUnknownOwner }
  if ([long]$Remote.Exp -gt [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() + $script:CredentialMaxAheadMs) { throw $script:CredentialTooFar }
}

function Read-RemoteCredential {
  param($Remote)
  try { $cred = (Get-DriveText $Remote.Id) | ConvertFrom-Json } catch { throw "jeton du Drive invalide" }
  if ($null -eq $cred -or [string]::IsNullOrEmpty([string]$cred.claudeAiOauth.accessToken)) { throw "jeton du Drive invalide" }
  if ((Get-CredentialExpiry $cred) -ne [long]$Remote.Exp) { throw "jeton du Drive invalide" }
  return $cred
}

function Send-LocalCredential {
  param($Acc, $Folders, $Remote, $Local)
  $id = ""
  if ($null -ne $Remote) { $id = $Remote.Id }
  $props = @{ exp = ("" + (Get-CredentialExpiry $Local)) }
  $who = Get-AccountEmail $Acc
  if ($who) { $props["who"] = $who }
  $json = $Local | ConvertTo-Json -Depth 10 -Compress
  $null = Send-DriveText $Folders.Credentials (Get-CredentialName $Acc) $json $props $id
}

function Sync-CredentialUnlocked {
  param($Acc, $Folders, $Listing)
  $local = Read-LocalCredential $Acc
  $remote = $Listing[(Get-CredentialName $Acc)]
  Assert-CredentialOwner $Acc $remote
  $remoteExp = [long]0
  if ($null -ne $remote) { $remoteExp = [long]$remote.Exp }
  $pick = Select-FresherCredential (Get-CredentialExpiry $local) $remoteExp
  if ($pick -eq "local") { Send-LocalCredential $Acc $Folders $remote $local }
  if ($pick -ne "remote") { return $pick }
  Assert-RemoteCredentialTrusted $Acc $remote
  $cred = Read-RemoteCredential $remote
  if ((Get-CredentialExpiry (Read-LocalCredential $Acc)) -ge $remoteExp) { return "same" }
  Write-AccountCredential $Acc $cred
  return "remote"
}

function Sync-AccountCredential {
  param($Acc, $Folders, $Listing)
  return Invoke-WithFileLock $script:CredLockPath $script:CredLockWaitMs "jetons en cours de synchro" { Sync-CredentialUnlocked $Acc $Folders $Listing }
}

function Sync-DriveCredentials {
  param($Folders, $Accs)
  $listing = Get-DriveListing $Folders.Credentials
  $failed = 0
  foreach ($a in $Accs) { try { $null = Sync-AccountCredential $a $Folders $listing } catch { $failed++ } }
  return $failed
}

function Sync-OneCredential {
  param($Acc)
  $f = Get-DriveFolders
  return Sync-AccountCredential $Acc $f (Get-DriveListing $f.Credentials)
}

function Receive-DriveCredential {
  param($Acc)
  if (-not (Test-DriveConnected)) { return $null }
  try { if ((Sync-OneCredential $Acc) -eq "remote") { return Read-AccountCredential $Acc } } catch { Write-Verbose $_.Exception.Message }
  return $null
}

function Send-DriveCredential {
  param($Acc)
  if (-not (Test-DriveConnected)) { return }
  try { $null = Sync-OneCredential $Acc } catch { Write-Verbose $_.Exception.Message }
}

function Test-CredentialUsable {
  param($Cred)
  return (Get-CredentialExpiry $Cred) -gt [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() + $script:CredentialMarginMs
}
