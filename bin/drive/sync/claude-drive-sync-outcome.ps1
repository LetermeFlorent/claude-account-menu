. Import-ClmModule claude-drive-lock, claude-drive-config, claude-drive-folders, claude-drive-sessions, claude-text

function Test-DriveSyncClean {
  param($Res)
  return $Res.Ok -and -not $Res.Error -and $Res.Left -eq 0 -and -not $Res.Stopped
}

function Set-DriveSyncOutcome {
  param($Res, [string]$Run)
  if ($Run -eq "left") { $Res.Ok = $true; $Res.Busy = $true; return }
  if ($Run -eq "done" -and $Res.Error) { try { Reset-DriveFoldersCheck } catch { Write-Verbose $_.Exception.Message } }
  if ($Run -ne "skipped") { return }
  $Res.Ok = $true
  $Res.Shared = $true
  $Res.Away = $null
  $Res.At = Get-DriveLastSync
}

function Set-DriveSyncError {
  param($Res, $ErrorRecord)
  if (Test-LeftToOtherClm $ErrorRecord) { $Res.Ok = $true; $Res.Error = ""; $Res.Busy = $true; return }
  $Res.Ok = $false
  $Res.Error = $ErrorRecord.Exception.Message
  $Res.Blocked = $ErrorRecord.Exception.Data["Blocked"] -eq $true
  try { Reset-DriveFoldersCheck } catch { Write-Verbose $_.Exception.Message }
}

function Get-DriveBusyText {
  return Get-ClmText "drive.sync.replaced"
}

function Get-DriveSyncElsewhereText {
  param($Res)
  if ($Res.Shared) { return (Get-ClmText "drive.sync.sharedText") }
  return Get-LeftToOtherClm
}

function Get-SyncNotice {
  param($Result)
  $t = ""
  $refused = @($Result.Refused | Where-Object { $_ })
  $late = @($Result.Late | Where-Object { $_ })
  if ($refused.Count -gt 0) { $t += " ; " + (Get-ClmText "drive.notice.refused" @((@($refused | Select-Object -First 3) -join ", "))) }
  if ($late.Count -gt 0) { $t += " ; " + (Get-ClmText "drive.notice.late" @(($late -join ", "))) }
  return $t
}

function Get-DriveSyncMsg {
  param($Result)
  if ($Result.Error) { return (Get-ClmText "drive.msg.line" @($Result.Error)) + (Get-SyncNotice $Result) }
  if ($Result.Busy -or $Result.Shared) { return (Get-ClmText "drive.msg.line" @((Get-DriveSyncElsewhereText $Result))) }
  if ($Result.Stopped) { return (Get-ClmText "drive.msg.line" @((Get-ClmText "drive.msg.stopped"))) }
  $t = (Get-ClmText "drive.msg.line" @((Get-ClmText "drive.msg.done" @($Result.Up, $Result.Down, $Result.Deleted, $Result.Conflicts))))
  if ($Result.Left -gt 0) { $t += ", " + (Get-ClmText "drive.msg.left" @($Result.Left)) }
  return $t + (Get-SyncNotice $Result)
}

function Add-SyncStep {
  param($Res, [Diagnostics.Stopwatch]$Watch, [string]$Name)
  Write-WatchLog ("synchro passe " + $Res.Pass + " " + $Name + " " + $Watch.ElapsedMilliseconds + " ms")
  $Watch.Restart()
}

function Write-SyncTotal {
  param($Res, [Diagnostics.Stopwatch]$Watch)
  if ($Res.Pass -gt 0) { Write-WatchLog ("synchro total " + $Watch.ElapsedMilliseconds + " ms, " + $Res.Pass + " passes") }
}
