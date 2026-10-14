. (Join-Path $PSScriptRoot "claude-drive-transfer.ps1")
$script:AwaySeconds = 12 * 3600
$script:CredentialMarginMs = 60000

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

function Sync-AccountCredential {
  param($Acc, $Folders, $Listing)
  $name = Get-CredentialName $Acc
  $local = Read-AccountCredential $Acc
  $remote = $Listing[$name]
  $remoteExp = [long]0
  if ($null -ne $remote) { $remoteExp = [long]$remote.Exp }
  $pick = Select-FresherCredential (Get-CredentialExpiry $local) $remoteExp
  if ($pick -eq "remote") {
    Write-AccountCredential $Acc ((Get-DriveText $remote.Id) | ConvertFrom-Json)
  } elseif ($pick -eq "local") {
    $id = ""
    if ($null -ne $remote) { $id = $remote.Id }
    $json = $local | ConvertTo-Json -Depth 10 -Compress
    $null = Send-DriveText $Folders.Credentials $name $json @{ exp = ("" + (Get-CredentialExpiry $local)) } $id
  }
  return $pick
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
  try { if ((Sync-OneCredential $Acc) -eq "remote") { return Read-AccountCredential $Acc } } catch {}
  return $null
}

function Send-DriveCredential {
  param($Acc)
  if (-not (Test-DriveConnected)) { return }
  try { $null = Sync-OneCredential $Acc } catch {}
}

function Test-CredentialUsable {
  param($Cred)
  return (Get-CredentialExpiry $Cred) -gt [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() + $script:CredentialMarginMs
}

function Set-DrivePresence {
  param($Acc, [bool]$Open)
  $f = Get-DriveFolders
  $name = (Get-DrivePcName) + ".json"
  $v = "0"
  if ($Open) { $v = "" + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
  $own = (Get-DriveListing $f.Presence)[$name]
  if ($null -ne $own) { Set-DriveProps $own.Id @{ $Acc.Dir = $v }; return }
  $null = Send-DriveText $f.Presence $name "{}" @{ $Acc.Dir = $v } ""
}

function Get-AwayMap {
  param($Listing, [string]$Pc, [long]$NowSec)
  $map = @{}
  foreach ($name in $Listing.Keys) {
    $other = $name -replace "\.json$", ""
    if ($other -eq $Pc) { continue }
    $props = $Listing[$name].Props
    foreach ($dir in $props.Keys) {
      $t = [long]$props[$dir]
      if ($t -gt 0 -and $NowSec - $t -lt $script:AwaySeconds) { $map[$dir] = $other }
    }
  }
  return $map
}
