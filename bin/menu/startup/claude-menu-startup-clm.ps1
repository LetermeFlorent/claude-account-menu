. Import-ClmModule claude-self-update, claude-machine-lock, claude-text
$script:ClmLockPollMs = 250
$script:ClmStepLock = $null

function Close-ClmStepLock {
  Close-MachineLock $script:ClmStepLock
  $script:ClmStepLock = $null
}

function Start-ClmWork {
  param($Step, [string]$Reader, $Item, [string]$Text, [double]$Now, [string]$Module = "claude-self-update")
  $Step.Work = Start-UsageLoader @(, $Item) (Get-ClmModulePath $Module) $Reader
  $Step.Reader = $Reader
  $Step.State = "run"
  $null = Set-StartupProgress $Step -1 $Text $Now
}

function Complete-ClmStep {
  param($Step, [string]$Kind, [string]$Text, [double]$Now)
  Close-ClmStepLock
  Complete-StartupStep $Step $Kind $Text $Now
}

function Complete-ClmFind {
  param($Su, $Step, $State, $R, [double]$Now)
  if ($R.Error -eq (Get-ClmUnknownText)) { $Su.ClmError = $R.Error; $State.Msg = Add-ClmFailure @("", $script:Ink.Dim) $R.Error }
  if ($R.Error) { Complete-ClmStep $Step "failed" (Get-ClmText "update.startup.searchFailed") $Now; return }
  if (-not (Test-ClmOutdated (Read-ClmVersion) $R.Value)) { Write-ClmChecked; Complete-ClmStep $Step "ok" (Get-ClmText "update.startup.upToDate") $Now; return }
  $Step.Found = $R.Value
  if ($Su.Quit) { Complete-ClmStep $Step "ok" (Get-ClmText "update.startup.availableNotInstalled" @((Get-ClmName $R.Value))) $Now; return }
  Start-ClmWork $Step "Install-ClmVersion" $R.Value (Get-ClmText "update.startup.installing" @((Format-ClmVersion $R.Value))) $Now
}

function Complete-ClmRestart {
  param($Su, $Step, [string]$Text, [double]$Now)
  if (-not $Su.Quit) { $Text = Get-ClmText "update.startup.withRestart" @($Text); $script:ClmUpdated = $true; $Su.Exit = @{ Name = "restart" } }
  Complete-ClmStep $Step "updated" $Text $Now
}

function Complete-ClmInstall {
  param($Su, $Step, $State, $R, [double]$Now)
  if ($R.Error) {
    $Su.ClmError = $R.Error
    $State.Msg = Add-ClmFailure @("", $script:Ink.Dim) $R.Error
    Complete-ClmStep $Step "failed" (Get-ClmText "update.startup.installFailed" @($R.Error)) $Now
    return
  }
  Complete-ClmRestart $Su $Step (Get-ClmText "update.startup.installed" @((Get-ClmName $Step.Found))) $Now
}

function Enter-ClmStepLock {
  param($Su, $Step, [double]$Now, $State = $null)
  if ($Now -lt $Step.LockAt) { return $false }
  $Step.LockAt = $Now + $script:ClmLockPollMs
  Close-ClmStepLock
  $script:ClmStepLock = Open-MachineLock $script:ClmUpdateLock
  if ($null -eq $script:ClmStepLock -and $Now -lt $Step.LockEnd) { return Set-StartupProgress $Step -1 (Get-ClmText "update.startup.waitOther") $Now }
  if ($null -eq $script:ClmStepLock) { Complete-ClmStep $Step "ok" (Get-ClmText "update.startup.leftToOther") $Now; return $true }
  try { $null = Start-ClmLocked $Su $Step $Now $State }
  catch { Close-ClmStepLock; throw }
  return $true
}

function Start-ClmLocked {
  param($Su, $Step, [double]$Now, $State = $null)
  $skip = Get-ClmUpdateSkip $script:ClmLoadedSha
  if ($skip -eq "replaced") { Complete-ClmRestart $Su $Step (Get-ClmText "update.startup.byPeer") $Now; return }
  if ($skip -eq "fresh") { Complete-ClmStep $Step "ok" (Get-ClmText "update.startup.upToDate") $Now; return }
  if (-not (Test-ClmVersionKnown (Read-ClmVersion))) { Complete-ClmFind $Su $Step $State @{ Error = (Get-ClmUnknownText) } $Now; return }
  Start-ClmWork $Step "Get-LatestClm" 0 (Get-ClmText "update.startup.searching") $Now "claude-self-latest"
}

function Step-ClmStartup {
  param($Su, $Step, $State, [double]$Now)
  if ($Step.State -eq "wait") {
    $script:ClmChecked = $true
    $Step.State = "lock"
    $Step.LockAt = $Now
    $Step.LockEnd = $Now + $script:ClmUpdateWaitMs
  }
  if ($Step.State -eq "lock") { return Enter-ClmStepLock $Su $Step $Now $State }
  $r = Receive-LoaderValue $Step.Work
  if ($null -eq $r) { return $false }
  if ($Step.Reader -eq "Get-LatestClm") { Complete-ClmFind $Su $Step $State $r $Now }
  else { Complete-ClmInstall $Su $Step $State $r $Now }
  return $true
}
