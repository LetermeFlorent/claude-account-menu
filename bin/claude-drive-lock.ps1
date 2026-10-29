. Import-ClmModule claude-machine-lock
$script:DriveSyncLock = "drive"
$script:AccountsSyncLock = "sync"
$script:DriveCredsLock = "drive-creds"
$script:DriveFoldersLock = "drive-folders"
$script:DriveWatchLock = "drive-watch"
$script:LeftToOtherClm = "laissee a un autre clm"
$script:LockStampKeepMs = 3600000

function Get-LockNow {
  return [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
}

function Invoke-WithMachineLock {
  param([string]$Name, [int]$WaitMs, [scriptblock]$Action, [string]$BusyText = $script:LeftToOtherClm)
  $lock = Open-MachineLock $Name $WaitMs
  if ($null -eq $lock) { throw $BusyText }
  try { & $Action } finally { Close-MachineLock $lock }
}

function Test-LeftToOtherClm {
  param($ErrorRecord)
  return $null -ne $ErrorRecord -and $ErrorRecord.Exception.Message -eq $script:LeftToOtherClm
}

function Test-MachineLockHeld {
  param([string]$Name)
  $lock = Open-MachineLock $Name
  if ($null -eq $lock) { return $true }
  Close-MachineLock $lock
  return $false
}

function Write-LockDone {
  param([string]$Name, [long]$StartedMs)
  Write-MachineStamp $Name ("" + $StartedMs)
}

function Test-LockDoneSince {
  param([string]$Name, [long]$AskedMs)
  $text = Read-MachineStamp $Name $script:LockStampKeepMs
  if ($text -notmatch "^[0-9]{1,15}$") { return $false }
  return [long]$text -ge $AskedMs
}

function Invoke-MachineOnce {
  param([string]$Name, [int]$WaitMs, [scriptblock]$Action, [switch]$Always)
  $asked = Get-LockNow
  $lock = Open-MachineLock $Name $WaitMs
  if ($null -eq $lock) { return "left" }
  try {
    if (-not $Always -and (Test-LockDoneSince $Name $asked)) { return "skipped" }
    $started = Get-LockNow
    $out = @(& $Action)
    if ($out.Count -gt 0 -and $out[-1] -is [bool] -and $out[-1]) { Write-LockDone $Name $started }
    return "done"
  } finally { Close-MachineLock $lock }
}
