. Import-ClmModule claude-machine-lock
$script:ClaudeUpdateLock = "claude-update"
$script:ClaudeCheckStamp = "claude-check"
$script:ClaudeUpdateWaitMs = 300000
$script:ClaudeCheckFreshMs = 120000
$script:ClaudeStampKinds = @("ok", "updated")
$script:ClaudeWaitText = "attente d'un autre clm qui met a jour Claude Code..."
$script:ClaudeLeftText = "mise a jour de Claude Code laissee a un autre clm"

function ConvertTo-ClaudeCheckText {
  param($Outcome)
  if ($Outcome.Kind -eq "updated" -and $Outcome.Text -match "-> (\S+)$") { return "Claude Code a jour (" + $Matches[1] + ")" }
  return $Outcome.Text
}

function Write-ClaudeChecked {
  param($Kinds, $Last)
  if ($null -eq $Last) { return }
  foreach ($k in @($Kinds)) { if ($script:ClaudeStampKinds -notcontains $k) { return } }
  try { Write-MachineStamp $script:ClaudeCheckStamp ("" + $PID + " " + (ConvertTo-ClaudeCheckText $Last)) } catch { Write-Verbose $_.Exception.Message }
}

function Get-ClaudeCheckedOutcome {
  $raw = Read-MachineStamp $script:ClaudeCheckStamp $script:ClaudeCheckFreshMs
  if ($raw -notmatch "^([0-9]{1,10}) (.+)$" -or [long]$Matches[1] -eq $PID) { return $null }
  return New-Outcome "ok" $Matches[2]
}

function Open-ClaudeTextLock {
  $lock = Open-MachineLock $script:ClaudeUpdateLock
  if ($null -ne $lock -or $null -ne (Get-ClaudeCheckedOutcome)) { return $lock }
  Write-Host ("  " + $script:ClaudeWaitText) -ForegroundColor DarkGray
  return Open-MachineLock $script:ClaudeUpdateLock $script:ClaudeUpdateWaitMs
}
