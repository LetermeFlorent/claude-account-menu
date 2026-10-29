. Import-ClmModule claude-self-update, claude-machine-lock
$script:ClmLockPollMs = 250
$script:ClmWaitStepText = "attente d'un autre clm"
$script:ClmByPeerText = "nouvelle version installee par un autre clm"

function Start-ClmWork {
  param($Step, [string]$Reader, $Item, [string]$Text, [double]$Now)
  $Step.Work = Start-UsageLoader @(, $Item) (Join-Path $PSScriptRoot "claude-self-update.ps1") $Reader
  $Step.Reader = $Reader
  $Step.State = "run"
  $null = Set-StartupProgress $Step -1 $Text $Now
}

function Complete-ClmStep {
  param($Step, [string]$Kind, [string]$Text, [double]$Now)
  Close-MachineLock $Step.Lock
  $Step.Lock = $null
  Complete-StartupStep $Step $Kind $Text $Now
}

function Complete-ClmFind {
  param($Su, $Step, $State, $R, [double]$Now)
  if ($R.Error -eq $script:ClmUnknownText) { $Su.ClmError = $R.Error; $State.Msg = Add-ClmFailure @("", $script:Ink.Dim) $R.Error }
  if ($R.Error) { Complete-ClmStep $Step "failed" "recherche impossible" $Now; return }
  if ($null -eq $R.Value) { Write-ClmChecked; Complete-ClmStep $Step "ok" "a jour" $Now; return }
  $Step.Found = $R.Value
  if ($Su.Quit) { Complete-ClmStep $Step "ok" ((Get-ClmName $R.Value) + " disponible, pas installee") $Now; return }
  Start-ClmWork $Step "Install-ClmVersion" $R.Value ("installation " + (Format-ClmVersion $R.Value)) $Now
}

function Complete-ClmRestart {
  param($Su, $Step, [string]$Text, [double]$Now)
  if (-not $Su.Quit) { $Text += ", redemarrage"; $script:ClmUpdated = $true; $Su.Exit = @{ Name = "restart" } }
  Complete-ClmStep $Step "updated" $Text $Now
}

function Complete-ClmInstall {
  param($Su, $Step, $State, $R, [double]$Now)
  if ($R.Error) {
    $Su.ClmError = $R.Error
    $State.Msg = Add-ClmFailure @("", $script:Ink.Dim) $R.Error
    Complete-ClmStep $Step "failed" ("installation impossible : " + $R.Error) $Now
    return
  }
  Complete-ClmRestart $Su $Step ((Get-ClmName $Step.Found) + " installee") $Now
}

function Enter-ClmStepLock {
  param($Su, $Step, [double]$Now)
  if ($Now -lt $Step.LockAt) { return $false }
  $Step.LockAt = $Now + $script:ClmLockPollMs
  $Step.Lock = Open-MachineLock $script:ClmUpdateLock
  if ($null -eq $Step.Lock -and $Now -lt $Step.LockEnd) { return Set-StartupProgress $Step -1 $script:ClmWaitStepText $Now }
  if ($null -eq $Step.Lock) { Complete-ClmStep $Step "ok" "laissee a un autre clm" $Now; return $true }
  try { $null = Start-ClmLocked $Su $Step $Now }
  catch { Close-MachineLock $Step.Lock; $Step.Lock = $null; throw }
  return $true
}

function Start-ClmLocked {
  param($Su, $Step, [double]$Now)
  $skip = Get-ClmUpdateSkip $script:ClmLoadedSha
  if ($skip -eq "replaced") { Complete-ClmRestart $Su $Step $script:ClmByPeerText $Now; return }
  if ($skip -eq "fresh") { Complete-ClmStep $Step "ok" "a jour" $Now; return }
  Start-ClmWork $Step "Find-ClmUpdate" 0 "recherche d'une nouvelle version" $Now
}

function Step-ClmStartup {
  param($Su, $Step, $State, [double]$Now)
  if ($Step.State -eq "wait") {
    $script:ClmChecked = $true
    $Step.State = "lock"
    $Step.LockAt = $Now
    $Step.LockEnd = $Now + $script:ClmUpdateWaitMs
  }
  if ($Step.State -eq "lock") { return Enter-ClmStepLock $Su $Step $Now }
  $r = Receive-LoaderValue $Step.Work
  if ($null -eq $r) { return $false }
  if ($Step.Reader -eq "Find-ClmUpdate") { Complete-ClmFind $Su $Step $State $r $Now }
  else { Complete-ClmInstall $Su $Step $State $r $Now }
  return $true
}
