if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-drive-sync.ps1")) { . (Join-Path $PSScriptRoot "claude-drive-sync.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-drive-watch-launch.ps1")) { . (Join-Path $PSScriptRoot "claude-drive-watch-launch.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-drive-watch-fs.ps1")) { . (Join-Path $PSScriptRoot "claude-drive-watch-fs.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-drive-watch-plan.ps1")) { . (Join-Path $PSScriptRoot "claude-drive-watch-plan.ps1") }
$script:DriveWatchLogName = "watch.log"
$script:DriveWatchLogMaxBytes = 262144

function Write-WatchLog {
  param([string]$Text)
  try {
    $null = [IO.Directory]::CreateDirectory($script:DriveSessionDir)
    $path = Join-Path $script:DriveSessionDir $script:DriveWatchLogName
    if ([IO.File]::Exists($path) -and (New-Object IO.FileInfo $path).Length -gt $script:DriveWatchLogMaxBytes) { [IO.File]::Delete($path) }
    [IO.File]::AppendAllText($path, ([DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss") + " " + $Text + "`n"))
  } catch {}
}

function Update-WatchFs {
  param($St)
  $accs = @(Get-Accounts)
  $roots = @(Get-SyncRoots $accs)
  if ($null -ne $St.Fs -and $St.Fs.Key -eq ($roots -join "|")) { return }
  Stop-WatchFs $St.Fs
  $St.Fs = New-WatchFsContext $script:HomeDir $roots (Get-SyncPatterns $accs) $script:RegistryPath
  Start-WatchFs $St.Fs
  if ($St.Fs.Blind) { Write-WatchLog "surveillance des fichiers indisponible, synchro reguliere a la place" }
}

function Invoke-WatchSync {
  if (Test-DriveAuto) { return Invoke-DriveSync $null 0 }
  $res = New-SyncResult
  try {
    $res.Failed = [int](Sync-DriveCredentials (Get-DriveFolders) @(Get-Accounts))
    $res.Ok = $true
  } catch { $res.Error = $_.Exception.Message }
  if ($res.Failed -gt 0) { $res.Error = "" + $res.Failed + " identifiant(s) en echec" }
  return $res
}

function Close-WatchEnded {
  param($St)
  foreach ($dir in @(Get-WatchClosedDirs $St)) {
    try { Set-DrivePresence @{ Dir = $dir } $false } catch { Write-WatchLog ("presence " + $dir + " : " + $_.Exception.Message) }
  }
  foreach ($p in @($St.Ended.Keys)) {
    try { [IO.File]::Delete($p) } catch { $null = $script:DriveWatchGone.Add($p); Write-WatchLog ("session " + $p + " : " + $_.Exception.Message) }
  }
  $St.Ended.Clear()
  $St.EndedSince = 0
}

function Invoke-WatchPass {
  param($St, [bool]$Final)
  $r = Invoke-WatchSync
  if ($r.Error -and -not $r.Busy) { Write-WatchLog ("synchro : " + $r.Error) }
  if ($r.Up -gt 0 -or $r.Down -gt 0 -or $r.Deleted -gt 0) { Write-WatchLog (Get-DriveSyncMsg $r) }
  if (Complete-WatchPass $St $r $Final (Get-WatchNow)) { Close-WatchEnded $St }
}

function Invoke-WatchCheck {
  param($St)
  $St.RemoteAt = Get-WatchNow
  Update-WatchFs $St
  $folders = Get-DriveFolders
  $failed = [int](Sync-DriveCredentials $folders @(Get-Accounts))
  if ($failed -gt 0) { Write-WatchLog ("" + $failed + " identifiant(s) en echec") }
  if (-not (Test-DriveAuto)) { return }
  try { Invoke-WithDriveLock { if (Test-DriveFilesChanged $folders (Get-DrivePcName)) { $St.Due = $true } } }
  catch { if ($_.Exception.Message -ne $script:DriveBusyText) { throw } }
}

function Step-DriveWatch {
  param($St)
  Start-Sleep -Milliseconds $script:DriveWatchTickMs
  $now = Get-WatchNow
  if ($null -ne $St.Fs -and (Receive-WatchEvents $St.Fs)) { Add-WatchLocalChange $St $now }
  Update-WatchSessions $St $now
  if (-not (Test-WatchActive $St)) { return $false }
  if (Test-ClmReplaced) { Write-WatchLog "clm mis a jour, le veilleur repart avec la nouvelle version"; return $false }
  $action = Get-DriveWatchAction $St $now
  if ($action -eq "") { return $true }
  if (-not (Test-DriveConnected)) { return $false }
  try {
    if ($action -eq "check") { Invoke-WatchCheck $St }
    else { Invoke-WatchPass $St ($action -eq "final") }
  } catch { Write-WatchLog ($action + " : " + $_.Exception.Message) }
  return $true
}

function Invoke-DriveWatch {
  $lock = Open-DriveWatchLock
  if ($null -eq $lock) { return }
  $st = New-WatchState (Get-WatchNow)
  try {
    Write-WatchLog ("debut, processus " + $PID)
    try { Update-WatchFs $st } catch { Write-WatchLog ("surveillance : " + $_.Exception.Message) }
    while (Step-DriveWatch $st) {}
  } catch { Write-WatchLog ("arret : " + $_.Exception.Message) }
  finally {
    Stop-WatchFs $st.Fs
    $lock.Dispose()
    Write-WatchLog "fin"
  }
}
