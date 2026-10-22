$script:UpdateTries = 3
$script:UpdateRetryPause = 2
$script:UpdateBusyPause = 5
$script:UpdateBusyLimit = 60
$script:UpdateMissingText = "Claude Code introuvable, pas de mise a jour"

function Start-ClaudeProcess {
  param([string]$Exe, $Acc)
  if (-not $Exe -or -not (Test-Path -LiteralPath $Exe)) { return $null }
  return Invoke-InAccountEnv $Acc { Start-UpdateProcess $Exe }
}

function Set-UpdateProc {
  param($Run, $Proc)
  $Run.Proc = $Proc
  $Run.Srcs = @((New-LineSource $Proc.StandardOutput), (New-LineSource $Proc.StandardError))
  $Run.State = New-UpdateState
  $Run.Watch = $null
  $Run.Killed = ""
  $Run.ExitAt = -1.0
  $Run.Clock = [Diagnostics.Stopwatch]::StartNew()
}

function New-UpdateRun {
  param($Proc, [string]$Exe = "", $Acc = $null)
  $run = @{ Exe = $Exe; Acc = $Acc; Tries = 1; BusyFrom = -1.0; RetryAt = -1.0; CanRetry = $true; Last = $null; Total = [Diagnostics.Stopwatch]::StartNew(); Outcome = $null }
  Set-UpdateProc $run $Proc
  return $run
}

function Get-UpdateRetryPause {
  param($Run, $Outcome, [double]$Now)
  if ($Outcome.Kind -ne "failed" -or -not $Run.Exe -or -not $Run.CanRetry) { return -1 }
  if ($Run.State.Busy) {
    if ($Run.BusyFrom -lt 0) { $Run.BusyFrom = $Now }
    if ($Now - $Run.BusyFrom -lt $script:UpdateBusyLimit) { return $script:UpdateBusyPause }
    return -1
  }
  if ($Run.Tries -ge $script:UpdateTries) { return -1 }
  $Run.Tries++
  return $script:UpdateRetryPause
}

function Get-UpdateRetryLabel {
  param($Run)
  if (-not $Run.State.Busy) { return "nouvel essai (" + $Run.Tries + "/" + $script:UpdateTries + ")" }
  if ($Run.State.Holder) { return "attente d'une autre session (PID " + $Run.State.Holder + ")" }
  return "attente d'une autre session"
}

function Request-UpdateRetry {
  param($Run, $Outcome)
  $now = $Run.Total.Elapsed.TotalSeconds
  $pause = Get-UpdateRetryPause $Run $Outcome $now
  if ($pause -lt 0) { return $false }
  $label = Get-UpdateRetryLabel $Run
  $Run.Last = $Outcome
  $Run.State = New-UpdateState
  $Run.State.Retry = $label
  $Run.Watch = $null
  $Run.RetryAt = $now + $pause
  return $true
}

function Resume-UpdateTry {
  param($Run)
  if (-not $Run.CanRetry) { $Run.Outcome = $Run.Last; return $true }
  if ($Run.Total.Elapsed.TotalSeconds -lt $Run.RetryAt) { return $false }
  $Run.RetryAt = -1.0
  $label = $Run.State.Retry
  $proc = Start-ClaudeProcess $Run.Exe $Run.Acc
  if ($null -eq $proc) { $Run.Outcome = New-Outcome "failed" $script:UpdateMissingText; return $true }
  Set-UpdateProc $Run $proc
  $Run.State.Retry = $label
  return $false
}
