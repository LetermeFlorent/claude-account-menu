if (-not (Test-Path Function:\Import-ClmModule)) { . (Join-Path $PSScriptRoot "claude-import.ps1") }
. Import-ClmModule claude-drive-actions, claude-drive-creds, claude-drive-leftovers, claude-drive-changes,
  claude-drive-sessions, claude-drive-prefs, claude-drive-scope, claude-state, claude-drive-lock, claude-drive-sync-outcome, claude-text
$script:DriveLockWaitMs = 5000
$script:DriveExitBudgetMs = 30000

function New-SyncResult {
  return @{ Ok = $false; Error = ""; Busy = $false; Shared = $false; Stopped = $false; At = [long]0; Left = 0; Up = 0; Down = 0; Deleted = 0; Conflicts = 0; Failed = 0; Failure = ""; Total = 0; Away = @{}; Again = $false; Refused = (New-Object 'System.Collections.Generic.List[string]'); Late = @() }
}

function Set-DriveLastSync {
  param([long]$At)
  $c = Read-DriveConfig
  if ($null -eq $c) { return }
  $c["lastSync"] = $At
  Save-DriveConfig $c
}

function Get-FailureSuffix {
  param($Res)
  if (-not $Res.Failure) { return "" }
  return " (" + $Res.Failure + ")"
}

function Invoke-DriveSyncPass {
  param($Res, $Ctl, [long]$DeadlineMs, [bool]$Force)
  $keys = Get-SyncKeys
  $folders = Get-DriveFolders
  Assert-SyncKeysMatch $folders $keys
  $pc = Get-DrivePcName
  $accs = @(Get-Accounts)
  $Res.Failed += [int](Sync-DriveCredentials $folders $accs $keys)
  $presence = Get-DriveListing $folders.Presence
  Set-PresenceFormat $folders $presence $pc
  $Res.Late = Get-WaitingPcs $presence
  $Res.Away = Get-AwayMap $presence $pc ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
  $prefs = Start-SyncPrefs $folders $presence $pc $accs $Res $keys
  $roots = Get-SyncRoots $accs
  $state = Read-SyncBase $folders.Root $roots
  $patterns = @(Get-SyncPatterns $accs) + @($prefs.Excludes)
  $local = Get-LocalFiles $script:HomeDir $roots $patterns $state.Files $Ctl $DeadlineMs
  if ($local.Stopped) { $Res.Ok = $true; $Res.Stopped = $true; return }
  $local.Skipped.AddRange([string[]]@(Get-HeldPaths))
  $sealed = ConvertFrom-SealedListing (Get-DriveFilesListing $folders $pc) $keys
  $listing = $sealed.Files
  Complete-SyncPrefs $prefs $listing $Ctl $DeadlineMs
  $remote = Select-RemoteFiles $listing $patterns $roots
  $plan = Get-SyncPlan $local.Files $state.Files $remote $local.Skipped -Joining:($state.At -eq 0) -CaseFold:($script:OsName -ne "Linux")
  Assert-DeleteLimit $plan $state.Files.Count $Force $prefs.Erased
  $Res.Total = $plan.Count
  $registry = Get-RegistryMd5 $local.Files
  $ctx = @{ Folder = $folders.Files; Pc = $pc; State = $state; Local = $local.Files; Remote = $remote; Res = $Res; Keys = $keys }
  $completed = $false
  try { Invoke-SyncPlan $ctx $plan $Ctl $DeadlineMs; $completed = $true }
  finally {
    if ($completed -and $Res.Left -eq 0 -and $Res.Failed -eq 0) { $state.At = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
    Save-DriveState $state
  }
  Remove-SyncedOffSkills $prefs.Choice $patterns $state.Files
  if ($Res.Failed -gt 0) { $Res.Error = (Get-ClmText "drive.sync.failedFiles" @($Res.Failed, (Get-FailureSuffix $Res))); return }
  if ($Res.Left -eq 0 -and (Test-AllPcsCurrent $presence)) {
    $Res.Deleted += Remove-OwnLeftovers $listing $pc (Get-SyncPatterns $accs) $Ctl $DeadlineMs
    $null = Remove-DriveFiles $sealed.Twins $Ctl $DeadlineMs
  }
  $Res.Ok = $true
  $Res.Again = (Get-RegistryMd5 $state.Files) -ne $registry
  if ($Res.Left -eq 0) { $Res.At = $state.At; Set-DriveLastSync $state.At }
}

$script:FreshSyncSource = Join-Path $PSScriptRoot "claude-drive-sync.ps1"
$script:FreshSyncScript = Add-ClmGuardedLoad 'param($Source, $Ctl, $DeadlineMs, $Force) $ProgressPreference = "SilentlyContinue"; <ClmGuardedLoad>; if ($clmReplaced) { return @{ Replaced = $true } }; Invoke-DriveSync $Ctl $DeadlineMs -Force:$Force'

function Invoke-FreshDriveSync {
  param($Ctl, [long]$DeadlineMs, [bool]$Force)
  $res = New-SyncResult
  $ps = [PowerShell]::Create()
  try {
    [void]$ps.AddScript($script:FreshSyncScript).AddArgument($script:FreshSyncSource).AddArgument($Ctl).AddArgument($DeadlineMs).AddArgument($Force)
    $out = @($ps.Invoke())
    if ($out.Count -gt 0 -and $out[-1].Replaced -eq $true) { $res.Busy = $true; $res.Error = $script:DriveBusyText; return $res }
    if ($out.Count -gt 0 -and $out[-1] -is [hashtable]) { return $out[-1] }
    $res.Error = (Get-ClmText "drive.sync.freshFailed")
  } catch { $res.Error = (Get-ClmText "drive.sync.freshFailed") + " : " + $_.Exception.GetBaseException().Message }
  finally { $ps.Dispose() }
  return $res
}

function Invoke-DriveSync {
  param($Ctl = $null, [long]$DeadlineMs = 0, [switch]$Force)
  if (Test-ClmReplaced) { return Invoke-FreshDriveSync $Ctl $DeadlineMs $Force.IsPresent }
  $res = New-SyncResult
  try {
    $run = Invoke-MachineOnce $script:DriveSyncLock $script:DriveLockWaitMs -Always:$Force {
      Invoke-DriveSyncPass $res $Ctl $DeadlineMs $Force.IsPresent
      if ($res.Ok -and $res.Again -and $res.Left -eq 0) { $res.Ok = $false; Invoke-DriveSyncPass $res $Ctl $DeadlineMs $Force.IsPresent }
      Test-DriveSyncClean $res
    }
    Set-DriveSyncOutcome $res $run
  } catch { Set-DriveSyncError $res $_ }
  return $res
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

function Sync-DriveBeforeLaunch {
  param($Acc)
  if (-not (Test-DriveConnected)) { return }
  try {
    $null = Sync-OneCredential $Acc
    Set-DrivePresence $Acc $true
  } catch { if (-not (Test-LeftToOtherClm $_)) { Write-Host ("  " + (Get-ClmText "drive.warn" @($_.Exception.Message))) -ForegroundColor DarkYellow } }
}

function Sync-DriveAfterExit {
  param($Acc, [long]$DeadlineMs)
  if (-not (Test-DriveConnected)) { return }
  try { Set-DrivePresence $Acc $false } catch { Write-Verbose $_.Exception.Message }
  if (-not (Test-DriveAuto)) { Send-DriveCredential $Acc; return }
  Write-Host ("  " + (Get-ClmText "drive.syncing")) -ForegroundColor DarkGray
  $r = Invoke-DriveSync $null $DeadlineMs
  while ($r.Busy -and (Get-LockNow) -lt $DeadlineMs) { $r = Invoke-DriveSync $null $DeadlineMs }
  if ($r.Error -or $r.Left -gt 0 -or $r.Stopped) { Write-Host ("  " + (Get-DriveSyncMsg $r)) -ForegroundColor DarkYellow }
}
