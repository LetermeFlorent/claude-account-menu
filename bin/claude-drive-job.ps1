if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-drive-sync.ps1")) { . (Join-Path $PSScriptRoot "claude-drive-sync.ps1") }
$script:DriveJob = $null
$script:DriveQuitWaitMs = 2000
$script:DriveRetryMs = 60000
$script:DriveProbeMs = 1000

function New-DriveJob {
  param([bool]$Connected, [long]$Last)
  return @{ Loader = $null; Ctl = $null; Connected = $Connected; Last = $Last; Failed = $false; Busy = $false; RetryAt = [long]0; Away = @{}; Seen = ""; Notify = $false; Notice = $null; Elsewhere = $false; ProbeAt = [long]0 }
}

function Test-DriveLockHeld {
  try { $fs = [IO.File]::Open($script:DriveLockPath, "OpenOrCreate", "ReadWrite", "None") } catch { return $true }
  $fs.Dispose()
  return $false
}

function Update-DriveElsewhere {
  param($Job, [long]$NowMs)
  if (-not $Job.Connected -or $NowMs - $Job.ProbeAt -lt $script:DriveProbeMs) { return $false }
  $Job.ProbeAt = $NowMs
  $held = Test-DriveLockHeld
  if ($held -eq $Job.Elsewhere) { return $false }
  $Job.Elsewhere = $held
  if ($held) { return $true }
  if ($Job.Busy) { $Job.RetryAt = $NowMs }
  $last = Get-DriveLastSync
  if ($last -gt $Job.Last) { $Job.Last = $last }
  return $true
}

function Get-DriveLastSync {
  $c = Read-DriveConfig
  if ($null -eq $c) { return [long]0 }
  return [long]$c["lastSync"]
}

function Start-DriveJob {
  param($Job, [switch]$Hold)
  if ($null -eq $Job) { return }
  if ($null -ne $Job.Loader) { if (-not $Hold) { Resume-UsageLoader $Job.Loader }; return }
  $Job.Ctl = [hashtable]::Synchronized(@{ Stop = $false; Progress = "" })
  $Job.Seen = ""
  $Job.Loader = Start-UsageLoader @(, $Job.Ctl) (Join-Path $PSScriptRoot "claude-drive-sync.ps1") "Invoke-DriveSync" -Hold:$Hold
}

function Test-DriveJobRunning {
  param($Job)
  return $null -ne $Job -and $null -ne $Job.Loader -and -not (Test-UsageLoaderHeld $Job.Loader)
}

function Complete-DriveJob {
  param($Job)
  $res = Receive-UsageResults $Job.Loader
  $err = $Job.Loader.Ctl.Error
  Close-UsageLoader $Job.Loader
  $Job.Loader = $null
  $r = $null
  if ($res.Count -gt 0) { $r = $res[0][1]; if ($res[0][2]) { $err = $res[0][2] } }
  if ($r -isnot [hashtable]) { $r = @{ Ok = $false; Error = ("" + $err) } }
  if (-not $r.Error -and -not $r.Ok) { $r.Error = "synchro interrompue" }
  $Job.Busy = [bool]$r.Busy
  $Job.RetryAt = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() + $script:DriveRetryMs
  $Job.Failed = [bool]$r.Error -and -not $Job.Busy
  if ([long]$r.At -gt 0) { $Job.Last = [long]$r.At }
  if ($null -ne $r.Away) { $Job.Away = $r.Away }
  if ($Job.Notify -or $Job.Failed) { $Job.Notice = Get-DriveSyncMsg $r }
  $Job.Notify = $false
}

function Step-DriveJob {
  param($Job, [long]$NowMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
  if ($null -eq $Job) { return $false }
  if ($null -eq $Job.Loader -and $Job.Busy -and $NowMs -ge $Job.RetryAt) { Start-DriveJob $Job; return $true }
  if (-not (Test-DriveJobRunning $Job)) { return Update-DriveElsewhere $Job $NowMs }
  if ($Job.Loader.Ctl.Done) { Complete-DriveJob $Job; return $true }
  $p = "" + $Job.Ctl.Progress
  if ($p -eq $Job.Seen) { return $false }
  $Job.Seen = $p
  return $true
}

function Stop-DriveJob {
  param($Job, [int]$TimeoutMs = $script:DriveQuitWaitMs)
  if ($null -eq $Job -or $null -eq $Job.Loader) { return }
  if (Test-UsageLoaderHeld $Job.Loader) { $TimeoutMs = 0 }
  $Job.Ctl.Stop = $true
  Stop-UsageLoader $Job.Loader $TimeoutMs
  if ($Job.Loader.Ctl.Done) { $Job.Loader = $null }
}

function Get-DriveTag {
  param($Job)
  if ($null -eq $Job -or -not $Job.Connected) { return @("", $script:Ink.Dim) }
  if (Test-DriveJobRunning $Job) {
    $p = "" + $Job.Ctl.Progress
    if ($p) { return @(("sync " + $p), $script:Ink.Dim) }
    return @("sync...", $script:Ink.Dim)
  }
  if ($Job.Elsewhere) { return @("sync...", $script:Ink.Dim) }
  if ($Job.Busy) { return @("sync attente", $script:Ink.Dim) }
  if ($Job.Failed) { return @("sync erreur", $script:Ink.Alert) }
  if ($Job.Last -gt 0) { return @(("sync " + [DateTimeOffset]::FromUnixTimeSeconds($Job.Last).LocalDateTime.ToString("HH:mm")), $script:Ink.Dim) }
  return @("sync jamais", $script:Ink.Dim)
}

function Request-DriveSync {
  param($Job)
  if ($null -eq $Job -or -not $Job.Connected) { return @("  Drive non connecte : clm --drive-login", $script:Ink.Dim) }
  if (Test-DriveJobRunning $Job) { return @("  synchro Drive deja en cours", $script:Ink.Dim) }
  $Job.Notify = $true
  Start-DriveJob $Job
  return @("  synchro Drive lancee", $script:Ink.Dim)
}

function Get-AccountAway {
  param($Acc)
  if ($null -eq $script:DriveJob -or $null -eq $Acc) { return "" }
  $pc = $script:DriveJob.Away[[string]$Acc.Dir]
  if (-not $pc) { return "" }
  return "ouvert sur " + $pc
}

function Open-DriveJob {
  param([bool]$Start = $true)
  if ($null -ne $script:DriveJob) { return }
  $connected = Test-DriveConnected
  $script:DriveJob = New-DriveJob $connected (Get-DriveLastSync)
  if ($Start -and $connected -and (Test-DriveAuto)) { Start-DriveJob $script:DriveJob }
}
