. Import-ClmModule claude-drive-sealed, claude-drive-folders, claude-drive-presence, claude-state, claude-drive-lock, claude-text
$script:CredentialMarginMs = 60000
$script:CredLockWaitMs = 15000
$script:CredentialMaxAheadMs = [long]30 * 24 * 3600 * 1000
$script:CredentialArea = "credentials/"

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
  try { $raw = Read-SharedText $p } catch { throw (Get-ClmText "drive.cred.unreadable") }
  try { return $raw | ConvertFrom-Json } catch { return $null }
}

function Assert-CredentialOwner {
  param($Acc, $Remote)
  if ($null -eq $Remote -or $null -eq $Remote.Props) { return }
  $who = [string]$Remote.Props["who"]
  $mine = Get-AccountEmail $Acc
  if ($who -and -not $mine) { throw (Get-ClmText "drive.cred.unknownOwner") }
  if ($who -and $who -ne $mine) { throw (Get-ClmText "drive.cred.otherOwner" @($who)) }
}

function Assert-RemoteCredentialTrusted {
  param($Acc, $Remote)
  $who = ""
  if ($null -ne $Remote.Props) { $who = [string]$Remote.Props["who"] }
  if (-not $who) { throw (Get-ClmText "drive.cred.noOwner") }
  if (-not (Get-AccountEmail $Acc)) { throw (Get-ClmText "drive.cred.unknownOwner") }
  if ([long]$Remote.Exp -gt [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() + $script:CredentialMaxAheadMs) { throw (Get-ClmText "drive.cred.tooFar") }
}

function Read-RemoteCredential {
  param($Acc, $Remote, $Keys)
  $text = Get-SealedText $Remote.Id ($script:CredentialArea + (Get-CredentialName $Acc)) $Keys
  try { $cred = $text | ConvertFrom-Json } catch { throw (Get-ClmText "drive.cred.invalid") }
  if ($null -eq $cred -or [string]::IsNullOrEmpty([string]$cred.claudeAiOauth.accessToken)) { throw (Get-ClmText "drive.cred.invalid") }
  if ((Get-CredentialExpiry $cred) -ne [long]$Remote.Exp) { throw (Get-ClmText "drive.cred.invalid") }
  return $cred
}

function Send-LocalCredential {
  param($Acc, $Folders, $Remote, $Local, $Keys)
  $id = ""
  if ($null -ne $Remote) { $id = $Remote.Id }
  $props = @{ exp = ("" + (Get-CredentialExpiry $Local)) }
  $who = Get-AccountEmail $Acc
  if ($who) { $props["who"] = $who }
  $json = $Local | ConvertTo-Json -Depth 10 -Compress
  $name = Get-CredentialName $Acc
  $null = Send-SealedText @{ FolderId = $Folders.Credentials; Name = $name; Seal = ($script:CredentialArea + $name); Text = $json; Props = $props; Id = $id; Keys = $Keys }
}

function Sync-CredentialUnlocked {
  param($Acc, $Folders, $Listing, $Keys)
  $local = Read-LocalCredential $Acc
  $remote = $Listing[(Get-CredentialName $Acc)]
  Assert-CredentialOwner $Acc $remote
  $remoteExp = [long]0
  if ($null -ne $remote) { $remoteExp = [long]$remote.Exp }
  $pick = Select-FresherCredential (Get-CredentialExpiry $local) $remoteExp
  if ($pick -eq "local") { Send-LocalCredential $Acc $Folders $remote $local $Keys }
  if ($pick -ne "remote") { return $pick }
  Assert-RemoteCredentialTrusted $Acc $remote
  $cred = Read-RemoteCredential $Acc $remote $Keys
  if ((Get-CredentialExpiry (Read-LocalCredential $Acc)) -ge $remoteExp) { return "same" }
  Write-AccountCredential $Acc $cred
  return "remote"
}

function Sync-AccountCredential {
  param($Acc, $Folders, $Listing, $Keys = $null)
  if ($null -eq $Keys) { $Keys = Get-SyncKeys }
  $lock = Open-MachineLock $script:DriveCredsLock $script:CredLockWaitMs
  if ($null -eq $lock) { return "left" }
  try { return Sync-CredentialUnlocked $Acc $Folders $Listing $Keys } finally { Close-MachineLock $lock }
}

function Sync-DriveCredentials {
  param($Folders, $Accs, $Keys)
  $listing = Get-DriveListing $Folders.Credentials
  $failed = 0
  foreach ($a in $Accs) { try { $null = Sync-AccountCredential $a $Folders $listing $Keys } catch { $failed++ } }
  return $failed
}

function Sync-OneCredential {
  param($Acc)
  $keys = Get-SyncKeys
  $f = Get-DriveFolders
  return Sync-AccountCredential $Acc $f (Get-DriveListing $f.Credentials) $keys
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
