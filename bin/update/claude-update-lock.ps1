. Import-ClmModule claude-machine-lock, claude-text
$script:ClaudeUpdateLock = "claude-update"
$script:ClaudeCheckStamp = "claude-check"
$script:ClaudeUpdateWaitMs = 300000
$script:ClaudeCheckFreshMs = 120000
$script:ClaudeStampKinds = @("ok", "updated")

function Get-ClaudeCheckVersion {
  param($Outcome)
  if ($Outcome.Kind -eq "updated" -and $Outcome.Text -match "-> (\S+)$") { return $Matches[1] }
  if ($Outcome.Kind -eq "ok" -and $Outcome.Text -match "\((\S+)\)$") { return $Matches[1] }
  return "-"
}

function ConvertFrom-ClaudeCheckStamp {
  param([string]$Body)
  $ver = ""
  if ($Body -match "\((\S+)\)$") { $ver = $Matches[1] }
  elseif ($Body -match "^[0-9]\S*$") { $ver = $Body }
  if ($ver) { return Get-ClmText "update.claude.upToDateVersion" @($ver) }
  return Get-ClmText "update.claude.upToDate"
}

function Write-ClaudeChecked {
  param($Kinds, $Last)
  if ($null -eq $Last) { return }
  foreach ($k in @($Kinds)) { if ($script:ClaudeStampKinds -notcontains $k) { return } }
  try { Write-MachineStamp $script:ClaudeCheckStamp ("" + $PID + " " + (Get-ClaudeCheckVersion $Last)) } catch { Write-Verbose $_.Exception.Message }
}

function Get-ClaudeCheckedOutcome {
  $raw = Read-MachineStamp $script:ClaudeCheckStamp $script:ClaudeCheckFreshMs
  if ($raw -notmatch "^([0-9]{1,10}) (.+)$" -or [long]$Matches[1] -eq $PID) { return $null }
  return New-Outcome "ok" (ConvertFrom-ClaudeCheckStamp $Matches[2])
}

function Open-ClaudeTextLock {
  $lock = Open-MachineLock $script:ClaudeUpdateLock
  if ($null -ne $lock -or $null -ne (Get-ClaudeCheckedOutcome)) { return $lock }
  Write-Host ("  " + (Get-ClmText "update.claude.waitOther")) -ForegroundColor DarkGray
  return Open-MachineLock $script:ClaudeUpdateLock $script:ClaudeUpdateWaitMs
}
