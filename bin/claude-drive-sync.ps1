if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-drive-actions.ps1")) { . (Join-Path $PSScriptRoot "claude-drive-actions.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-drive-creds.ps1")) { . (Join-Path $PSScriptRoot "claude-drive-creds.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-drive-leftovers.ps1")) { . (Join-Path $PSScriptRoot "claude-drive-leftovers.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-drive-changes.ps1")) { . (Join-Path $PSScriptRoot "claude-drive-changes.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-drive-sessions.ps1")) { . (Join-Path $PSScriptRoot "claude-drive-sessions.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-drive-prefs.ps1")) { . (Join-Path $PSScriptRoot "claude-drive-prefs.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-drive-scope.ps1")) { . (Join-Path $PSScriptRoot "claude-drive-scope.ps1") }
$script:DriveLockPath = Join-Path (Get-HomeDir) ".clm-drive.lock"
$script:DriveLockWaitMs = 5000
$script:DriveExitBudgetMs = 30000
$script:DriveBusyText = "une autre synchro Drive est en cours"

function Invoke-WithDriveLock {
  param([scriptblock]$Action)
  Invoke-WithFileLock $script:DriveLockPath $script:DriveLockWaitMs $script:DriveBusyText $Action
}

function New-SyncResult {
  return @{ Ok = $false; Error = ""; Busy = $false; Stopped = $false; At = [long]0; Left = 0; Up = 0; Down = 0; Deleted = 0; Conflicts = 0; Failed = 0; Total = 0; Away = @{}; Again = $false }
}

function Set-DriveLastSync {
  param([long]$At)
  $c = Read-DriveConfig
  if ($null -eq $c) { return }
  $c["lastSync"] = $At
  Save-DriveConfig $c
}

function Invoke-DriveSyncPass {
  param($Res, $Ctl, [long]$DeadlineMs, [bool]$Force)
  $folders = Get-DriveFolders
  $pc = Get-DrivePcName
  $accs = @(Get-Accounts)
  $Res.Failed += [int](Sync-DriveCredentials $folders $accs)
  $presence = Get-DriveListing $folders.Presence
  Set-PresenceFormat $folders $presence $pc
  $Res.Away = Get-AwayMap $presence $pc ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
  $prefs = Start-SyncPrefs $folders $presence $pc $accs $Res
  $roots = Get-SyncRoots $accs
  $state = Read-SyncBase $folders.Root $roots
  $patterns = @(Get-SyncPatterns $accs) + @($prefs.Excludes)
  $local = Get-LocalFiles $script:HomeDir $roots $patterns $state.Files $Ctl $DeadlineMs
  if ($local.Stopped) { $Res.Ok = $true; $Res.Stopped = $true; return }
  $local.Skipped.AddRange([string[]]@(Get-HeldPaths))
  $listing = Get-DriveFilesListing $folders $pc
  Complete-SyncPrefs $prefs $listing $Ctl $DeadlineMs
  $remote = Select-RemoteFiles $listing $patterns $roots
  $plan = Get-SyncPlan $local.Files $state.Files $remote $local.Skipped -Joining:($state.At -eq 0) -CaseFold:($script:OsName -ne "Linux")
  Assert-DeleteLimit $plan $state.Files.Count $Force $prefs.Erased
  $Res.Total = $plan.Count
  $registry = Get-RegistryMd5 $local.Files
  $ctx = @{ Folder = $folders.Files; Pc = $pc; State = $state; Local = $local.Files; Remote = $remote; Res = $Res }
  try { Invoke-SyncPlan $ctx $plan $Ctl $DeadlineMs }
  finally {
    if ($Res.Left -eq 0 -and $Res.Failed -eq 0) { $state.At = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
    Save-DriveState $state
  }
  Remove-SyncedOffSkills $prefs.Choice $patterns $state.Files
  if ($Res.Failed -gt 0) { $Res.Error = "" + $Res.Failed + " fichier(s) en echec, nouvel essai a la prochaine synchro"; return }
  if ($Res.Left -eq 0 -and (Test-AllPcsCurrent $presence)) { $Res.Deleted += Remove-OwnLeftovers $listing $pc (Get-SyncPatterns $accs) $Ctl $DeadlineMs }
  $Res.Ok = $true
  $Res.Again = (Get-RegistryMd5 $state.Files) -ne $registry
  if ($Res.Left -eq 0) { $Res.At = $state.At; Set-DriveLastSync $state.At }
}

$script:FreshSyncSource = Join-Path $PSScriptRoot "claude-drive-sync.ps1"
$script:FreshSyncFailed = "synchro par la nouvelle version de clm impossible"
$script:FreshSyncScript = 'param($Source, $Ctl, $DeadlineMs, $Force) $ProgressPreference = "SilentlyContinue"; . $Source; Invoke-DriveSync $Ctl $DeadlineMs -Force:$Force'

function Invoke-FreshDriveSync {
  param($Ctl, [long]$DeadlineMs, [bool]$Force)
  $res = New-SyncResult
  $ps = [PowerShell]::Create()
  try {
    [void]$ps.AddScript($script:FreshSyncScript).AddArgument($script:FreshSyncSource).AddArgument($Ctl).AddArgument($DeadlineMs).AddArgument($Force)
    $out = @($ps.Invoke())
    if ($out.Count -gt 0 -and $out[-1] -is [hashtable]) { return $out[-1] }
    $res.Error = $script:FreshSyncFailed
  } catch { $res.Error = $script:FreshSyncFailed + " : " + $_.Exception.GetBaseException().Message }
  finally { $ps.Dispose() }
  return $res
}

function Invoke-DriveSync {
  param($Ctl = $null, [long]$DeadlineMs = 0, [switch]$Force)
  if (Test-ClmReplaced) { return Invoke-FreshDriveSync $Ctl $DeadlineMs $Force.IsPresent }
  $res = New-SyncResult
  try {
    Invoke-WithDriveLock {
      Invoke-DriveSyncPass $res $Ctl $DeadlineMs $Force.IsPresent
      if ($res.Ok -and $res.Again -and $res.Left -eq 0) { $res.Ok = $false; Invoke-DriveSyncPass $res $Ctl $DeadlineMs $Force.IsPresent }
    }
  } catch { $res.Ok = $false; $res.Error = $_.Exception.Message; $res.Busy = $res.Error -eq $script:DriveBusyText }
  return $res
}

function Get-DriveSyncMsg {
  param($Result)
  if ($Result.Error) { return "synchro Drive : " + $Result.Error }
  if ($Result.Stopped) { return "synchro Drive : interrompue pendant l'analyse, reprise a la prochaine synchro" }
  $t = "synchro Drive : " + $Result.Up + " envoyes, " + $Result.Down + " recus, " + $Result.Deleted + " supprimes, " + $Result.Conflicts + " conflits"
  if ($Result.Left -gt 0) { $t += ", " + $Result.Left + " restants pour la prochaine synchro" }
  return $t
}

function Sync-DriveBeforeLaunch {
  param($Acc)
  if (-not (Test-DriveConnected)) { return }
  try {
    $null = Sync-OneCredential $Acc
    Set-DrivePresence $Acc $true
  } catch { Write-Host ("  Drive : " + $_.Exception.Message) -ForegroundColor DarkYellow }
}

function Sync-DriveAfterExit {
  param($Acc, [long]$DeadlineMs)
  if (-not (Test-DriveConnected)) { return }
  try { Set-DrivePresence $Acc $false } catch {}
  if (-not (Test-DriveAuto)) { Send-DriveCredential $Acc; return }
  Write-Host "  synchro Drive..." -ForegroundColor DarkGray
  $r = Invoke-DriveSync $null $DeadlineMs
  if ($r.Error -or $r.Left -gt 0 -or $r.Stopped) { Write-Host ("  " + (Get-DriveSyncMsg $r)) -ForegroundColor DarkYellow }
}
