. Import-ClmModule claude-state, claude-file-io
$script:MachineLockExt = ".lock"
$script:MachineStampExt = ".done"

function Open-MachineLock {
  param([string]$Name, [int]$WaitMs = 0)
  return Enter-FileLock (Get-StatePath ($Name + $script:MachineLockExt)) $WaitMs
}

function Close-MachineLock {
  param($Lock)
  if ($null -ne $Lock) { $Lock.Dispose() }
}

function Write-MachineStamp {
  param([string]$Name, [string]$Text)
  $at = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  Write-TextFileAtomic (Get-StatePath ($Name + $script:MachineStampExt)) ("" + $at + " " + $Text)
}

function Read-MachineStamp {
  param([string]$Name, [long]$FreshMs)
  $path = Get-StatePath ($Name + $script:MachineStampExt)
  if (-not [IO.File]::Exists($path)) { return $null }
  try { $raw = Read-SharedText $path } catch { Write-Verbose $_.Exception.Message; return $null }
  if ($raw -notmatch "^([0-9]{1,15}) ([\s\S]*)$") { return $null }
  $age = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() - [long]$Matches[1]
  if ($age -lt 0 -or $age -gt $FreshMs) { return $null }
  return $Matches[2]
}
