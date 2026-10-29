param([string]$Bin, [string]$Lab, [string]$Dir, [string]$Id, [string]$Target)
$ErrorActionPreference = "Stop"
. (Join-Path $Lab "race-helpers.ps1")
. (Join-Path $PSScriptRoot "race-tally.ps1")
. (Join-Path $Bin "claude-import.ps1")
. Import-ClmModule claude-drive-sync
$script:FreshSyncSource = Join-Path $Target "race-entry.ps1"

function Invoke-SyncRun {
  $res = Invoke-FreshDriveSync $null 0 $false
  $seen = "" + $res.Seen
  $err = ""
  if (-not $res.Busy) { $err = "" + $res.Error }
  return @{ Seen = $seen; Stopped = (-not $seen -and -not $err); Error = $err }
}

Wait-RaceGate $Dir $Id
Invoke-RaceLoop $Dir $Id { Invoke-SyncRun }
