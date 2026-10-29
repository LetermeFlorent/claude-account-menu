param([string]$Bin, [string]$Dir, [string]$Id)
. (Join-Path $PSScriptRoot "drive-race-load.ps1") $Bin $Dir
. (Join-Path (Split-Path -Parent $PSScriptRoot) "race-helpers.ps1")

$script:DriveRacePassLog = Join-Path $Dir ("passes-" + $Id + ".log")
$script:DriveRaceOriginalPass = ${function:Invoke-DriveSyncPass}

function Add-DriveRacePass {
  param([string]$Kind)
  [IO.File]::AppendAllText($script:DriveRacePassLog, $Kind + " " + $Id + " " + [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() + "`n")
}

Set-Item function:Invoke-DriveSyncPass {
  param($Res, $Ctl, [long]$DeadlineMs, [bool]$Force)
  Add-DriveRacePass "start"
  Start-Sleep -Milliseconds 300
  try { & $script:DriveRaceOriginalPass $Res $Ctl $DeadlineMs $Force } finally { Add-DriveRacePass "end" }
}

Wait-RaceGate $Dir $Id
$res = Invoke-DriveSync
$kind = "done"
if ($res.Busy) { $kind = "left" } elseif ($res.Shared) { $kind = "skipped" }
$info = [ordered]@{ Ok = [bool]$res.Ok; Error = [string]$res.Error; Busy = [bool]$res.Busy; Shared = [bool]$res.Shared; Kind = $kind; Config = $script:DriveConfigPath; State = $script:DriveStatePath }
Write-TextFileAtomic (Join-Path $Dir ("result-" + $Id + ".json")) (ConvertTo-Json $info -Compress)
"result " + $Id + " " + $kind
