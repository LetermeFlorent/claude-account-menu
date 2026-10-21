$script:AwaySeconds = 12 * 3600
$script:SyncFormatKey = "fmt"
$script:SyncFormat = 2

function Get-PresenceProps {
  param($Acc, [bool]$Open)
  $v = "0"
  if ($Open) { $v = "" + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
  return @{ $Acc.Dir = $v; $script:SyncFormatKey = ("" + $script:SyncFormat) }
}

function Set-DrivePresence {
  param($Acc, [bool]$Open)
  $f = Get-DriveFolders
  $name = (Get-DrivePcName) + ".json"
  $props = Get-PresenceProps $Acc $Open
  $own = (Get-DriveListing $f.Presence)[$name]
  if ($null -ne $own) { Set-DriveProps $own.Id $props; return }
  $null = Send-DriveText $f.Presence $name "{}" $props ""
}

function Get-PresenceFormat {
  param($Entry)
  $n = 0
  if ($null -eq $Entry -or $null -eq $Entry.Props) { return 0 }
  if ([int]::TryParse([string]$Entry.Props[$script:SyncFormatKey], [ref]$n)) { return $n }
  return 0
}

function Set-PresenceFormat {
  param($Folders, $Presence, [string]$Pc)
  $name = $Pc + ".json"
  $own = $Presence[$name]
  if ((Get-PresenceFormat $own) -ge $script:SyncFormat) { return }
  $props = @{ $script:SyncFormatKey = ("" + $script:SyncFormat) }
  if ($null -ne $own) { Set-DriveProps $own.Id $props; $own.Props[$script:SyncFormatKey] = $props[$script:SyncFormatKey]; return }
  $r = Send-DriveText $Folders.Presence $name "{}" $props ""
  $Presence[$name] = @{ Id = $r.Id; Name = $name; Props = $props }
}

function Test-AllPcsCurrent {
  param($Presence)
  foreach ($k in $Presence.Keys) { if ((Get-PresenceFormat $Presence[$k]) -lt $script:SyncFormat) { return $false } }
  return $true
}

function Get-AwayMap {
  param($Listing, [string]$Pc, [long]$NowSec)
  $map = @{}
  foreach ($name in $Listing.Keys) {
    $other = $name -replace "\.json$", ""
    if ($other -eq $Pc) { continue }
    $props = $Listing[$name].Props
    foreach ($dir in $props.Keys) {
      if ($dir -eq $script:SyncFormatKey) { continue }
      $t = [long]$props[$dir]
      if ($t -gt 0 -and $NowSec - $t -lt $script:AwaySeconds) { $map[$dir] = $other }
    }
  }
  return $map
}

function Test-AccountAway {
  param($Acc)
  if (-not (Test-DriveConnected)) { return $false }
  try {
    $f = Get-DriveFolders
    $away = Get-AwayMap (Get-DriveListing $f.Presence) (Get-DrivePcName) ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
    return $away.ContainsKey([string]$Acc.Dir)
  } catch { return $false }
}
