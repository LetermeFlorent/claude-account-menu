. (Join-Path $PSScriptRoot "claude-drive-sync.ps1")
$script:DriveJob = $null
$script:DriveQuitWaitMs = 2000

function New-DriveJob {
  param([bool]$Connected, [long]$Last)
  return @{ Loader = $null; Ctl = $null; Connected = $Connected; Last = $Last; Failed = $false; Away = @{}; Seen = ""; Notify = $false; Notice = $null }
}

function Get-DriveLastSync {
  $c = Read-DriveConfig
  if ($null -eq $c) { return [long]0 }
  return [long]$c["lastSync"]
}

function Start-DriveJob {
  param($Job)
  if ($null -eq $Job -or $null -ne $Job.Loader) { return }
  $Job.Ctl = [hashtable]::Synchronized(@{ Stop = $false; Progress = "" })
  $Job.Seen = ""
  $Job.Loader = Start-UsageLoader @(, $Job.Ctl) (Join-Path $PSScriptRoot "claude-drive-sync.ps1") "Invoke-DriveSync"
}

function Test-DriveJobRunning {
  param($Job)
  return $null -ne $Job -and $null -ne $Job.Loader
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
  $Job.Failed = [bool]$r.Error
  if ([long]$r.At -gt 0) { $Job.Last = [long]$r.At }
  if ($null -ne $r.Away) { $Job.Away = $r.Away }
  if ($Job.Notify -or $Job.Failed) { $Job.Notice = Get-DriveSyncMsg $r }
  $Job.Notify = $false
}

function Step-DriveJob {
  param($Job)
  if (-not (Test-DriveJobRunning $Job)) { return $false }
  if ($Job.Loader.Ctl.Done) { Complete-DriveJob $Job; return $true }
  $p = "" + $Job.Ctl.Progress
  if ($p -eq $Job.Seen) { return $false }
  $Job.Seen = $p
  return $true
}

function Stop-DriveJob {
  param($Job, [int]$TimeoutMs = $script:DriveQuitWaitMs)
  if (-not (Test-DriveJobRunning $Job)) { return }
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
  if ($null -ne $script:DriveJob) { return }
  $connected = Test-DriveConnected
  $script:DriveJob = New-DriveJob $connected (Get-DriveLastSync)
  if ($connected -and (Test-DriveAuto)) { Start-DriveJob $script:DriveJob }
}
