. Import-ClmModule claude-self-version, claude-text, claude-sync-catalog, claude-sync-choice
$script:AwayHours = 12
$script:AwaySeconds = $script:AwayHours * 3600
$script:PresenceExt = ".json"
$script:PresenceExtTail = [regex]::Escape($script:PresenceExt) + "$"
$script:SyncFormatKey = "fmt"
$script:SyncFormat = 6
$script:McpFormat = 3

function Get-PresenceProps {
  param($Acc, [bool]$Open)
  $v = "0"
  if ($Open) { $v = "" + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
  return @{ $Acc.Dir = $v; $script:SyncFormatKey = ("" + $script:SyncFormat) }
}

function Set-DrivePresence {
  param($Acc, [bool]$Open)
  $f = Get-DriveFolders
  $name = (Get-DrivePcName) + $script:PresenceExt
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
  $name = $Pc + $script:PresenceExt
  $own = $Presence[$name]
  if ((Get-PresenceFormat $own) -ge $script:SyncFormat) { return }
  $props = @{ $script:SyncFormatKey = ("" + $script:SyncFormat) }
  if ($null -ne $own) { Set-DriveProps $own.Id $props; $own.Props[$script:SyncFormatKey] = $props[$script:SyncFormatKey]; return }
  $r = Send-DriveText $Folders.Presence $name "{}" $props ""
  $Presence[$name] = @{ Id = $r.Id; Name = $name; Props = $props }
}

function Get-WaitingPcs {
  param($Presence, [int]$Format = $script:SyncFormat)
  $names = [string[]]@($Presence.Keys | Where-Object { (Get-PresenceFormat $Presence[$_]) -lt $Format } | ForEach-Object { $_ -replace $script:PresenceExtTail, "" })
  [Array]::Sort($names, [StringComparer]::OrdinalIgnoreCase)
  return ,$names
}

function Get-NewerPcs {
  param($Presence)
  $names = [string[]]@($Presence.Keys | Where-Object { (Get-PresenceFormat $Presence[$_]) -gt $script:SyncFormat } | ForEach-Object { $_ -replace $script:PresenceExtTail, "" })
  [Array]::Sort($names, [StringComparer]::OrdinalIgnoreCase)
  return ,$names
}

function Assert-ClmCurrent {
  param($Presence)
  $text = ""
  $release = Get-NewerClmRelease
  $newer = Get-NewerPcs $Presence
  if ($release -gt 0) { $text = Get-ClmText "drive.blocked.release" @($release) }
  elseif ($newer.Count -gt 0) { $text = Get-ClmText "drive.blocked.peer" @(($newer -join ", ")) }
  if (-not $text) { return }
  $e = New-Object Exception $text
  $e.Data["Blocked"] = $true
  throw $e
}

function Test-AllPcsCurrent {
  param($Presence)
  return (Get-WaitingPcs $Presence).Count -eq 0
}

function Get-AwayMap {
  param($Listing, [string]$Pc, [long]$NowSec)
  $map = @{}
  foreach ($name in $Listing.Keys) {
    $other = $name -replace $script:PresenceExtTail, ""
    if ($other -eq $Pc) { continue }
    $props = $Listing[$name].Props
    foreach ($dir in $props.Keys) {
      if ($dir -eq $script:SyncFormatKey -or $dir -eq "k") { continue }
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

function Remove-DrivePc {
  param([string]$Pc)
  if ($Pc -eq (Get-DrivePcName) -or -not $script:PcNamePattern.IsMatch($Pc)) { throw (Get-ClmText "drive.pc.removeSelf" @($Pc)) }
  $name = $Pc + $script:PresenceExt
  $entry = (Get-DriveListing (Get-DriveFolders).Presence)[$name]
  $recent = $false
  if ($null -ne $entry) {
    $recent = (Get-AwayMap @{ $name = $entry } "" ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())).Count -gt 0
    Remove-DriveFile $entry.Id
  }
  $cat = Read-SyncCatalog
  $cat.Pcs.Remove($Pc)
  foreach ($other in $cat.Pcs.Values) { $other.Took.Remove($Pc); $other.Asks.Remove($Pc) }
  Save-SyncCatalog $cat
  $null = Update-SyncChoice { param($c) $c.Asks.Remove($Pc) }
  return @{ Removed = $null -ne $entry; Recent = $recent }
}
