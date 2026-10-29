. Import-ClmModule claude-update-lock
$script:ClaudeLockPollMs = 250
$script:ClaudeWaitStepText = "attente d'un autre clm"
$script:ClaudeLeftStepText = "laissee a un autre clm"

function Add-ClaudeOutcome {
  param($Step, $Accounts, $Outcome)
  $Step.Parts += Format-UpdateMessage $Accounts $Outcome.Text
  $Step.Kinds += $Outcome.Kind
  $Step.Texts += ($Outcome.Text -replace "^Claude Code ", "")
  $Step.Last = $Outcome
}

function Close-ClaudeStepLock {
  Close-MachineLock $script:ClaudeStepLock
  $script:ClaudeStepLock = $null
}

function Complete-ClaudeStartup {
  param($Su, $Step, $State, [double]$Now)
  Close-ClaudeStepLock
  $State.Msg = Add-ClmFailure (Get-UpdateSummary $Step.Parts $Step.Kinds) $Su.ClmError
  $kind = Get-UpdateKind $Step.Kinds
  $text = $Step.Texts -join ", "
  if ($kind -eq "failed") { $text = "echec" }
  Complete-StartupStep $Step $kind $text $Now
}

function Enter-ClaudeStepLock {
  param($Su, $Step, $State, [double]$Now)
  if ($Now -lt $Step.LockAt) { return $false }
  $Step.LockAt = $Now + $script:ClaudeLockPollMs
  $script:ClaudeStepLock = Open-MachineLock $script:ClaudeUpdateLock
  $fresh = Get-ClaudeCheckedOutcome
  if ($null -ne $fresh) {
    foreach ($g in $Step.Groups) { Add-ClaudeOutcome $Step $g.Accounts $fresh }
    Complete-ClaudeStartup $Su $Step $State $Now
    return $true
  }
  if ($null -ne $script:ClaudeStepLock) { $Step.State = "run"; $null = Set-StartupProgress $Step -1 "recherche de mise a jour" $Now; return $true }
  if ($Now -lt $Step.LockEnd) { return Set-StartupProgress $Step -1 $script:ClaudeWaitStepText $Now }
  Complete-StartupStep $Step "ok" $script:ClaudeLeftStepText $Now
  return $true
}

function Open-ClaudeStartup {
  param($Step, [double]$Now)
  $Step.Groups = @(Get-UpdateGroups @(Get-Accounts))
  Close-ClaudeStepLock
  $Step.Group = 0; $Step.Run = $null; $Step.Last = $null
  $Step.Parts = @(); $Step.Kinds = @(); $Step.Texts = @()
  $Step.State = "lock"; $Step.LockAt = $Now; $Step.LockEnd = $Now + $script:ClaudeUpdateWaitMs; $Step.NextAt = $Now
  $script:MenuUpdated = $true
}

function Step-ClaudeStartup {
  param($Su, $Step, $State, [double]$Now)
  if ($Step.State -eq "wait") { Open-ClaudeStartup $Step $Now }
  if ($Step.State -eq "lock") { return Enter-ClaudeStepLock $Su $Step $State $Now }
  if ($Now -lt $Step.NextAt) { return $false }
  $Step.NextAt = $Now + $script:StartupPollMs
  if ($Su.Quit -and $null -ne $Step.Run) { $Step.Run.CanRetry = $false }
  if ($null -ne $Step.Run -and -not (Step-ClaudeUpdate $Step.Run)) {
    $t = Get-UpdateTick $Step.Run.State $Step.Run.Watch
    return Set-StartupProgress $Step $t.Pct (($t.Label + "  " + $t.Detail).Trim()) $Now
  }
  if ($null -ne $Step.Run) { Add-ClaudeOutcome $Step $Step.Groups[$Step.Group - 1].Accounts $Step.Run.Outcome; $Step.Run = $null }
  if ($Step.Group -lt $Step.Groups.Count) {
    $g = $Step.Groups[$Step.Group]
    $Step.Group++
    $Step.Run = Start-ClaudeUpdate $g.Exe $g.Accounts[0]
    return $false
  }
  Write-ClaudeChecked $Step.Kinds $Step.Last
  Complete-ClaudeStartup $Su $Step $State $Now
  return $true
}
