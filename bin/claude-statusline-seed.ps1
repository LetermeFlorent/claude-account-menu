if (-not (Test-Path Function:\Import-ClmModule)) { . (Join-Path $PSScriptRoot "claude-import.ps1") }
$script:SeedStamp = Read-ClmStamp
$script:SeedHook = $MyInvocation.InvocationName -ne "."
if ($script:SeedHook -and $script:SeedStamp -ceq $script:ClmInstallingStamp) { exit 0 }
try { . Import-ClmModule claude-state-migrate } catch { if (-not $script:SeedHook -or (Test-ClmStampSteady $script:SeedStamp)) { throw } }
if ($script:SeedHook -and -not (Test-ClmStampSteady $script:SeedStamp)) { exit 0 }
if ($script:SeedHook) { $null = Invoke-StateMigration }
try { . Import-ClmModule claude-usage } catch { if (-not $script:SeedHook -or (Test-ClmStampSteady $script:SeedStamp)) { throw } }
if ($script:SeedHook -and -not (Test-ClmStampSteady $script:SeedStamp)) { exit 0 }

function Convert-ToEpoch {
  param($Iso)
  $at = ConvertTo-DateOffset $Iso
  if ($null -eq $at) { return $null }
  return $at.ToUnixTimeSeconds()
}

function Find-CurrentAccount {
  $dir = $env:CLAUDE_CONFIG_DIR
  if ([string]::IsNullOrWhiteSpace($dir)) { $dir = Join-Path $script:HomeDir ".claude" }
  $want = ConvertTo-PathKey $dir
  foreach ($a in Get-Accounts) {
    if ((ConvertTo-PathKey (Get-AccountPath $a)) -eq $want) { return $a }
  }
  return $null
}

. Import-ClmModule claude-machine-lock, claude-statusline-lock, claude-statusline-changes
$script:StatusLockName = "statusline"
$script:StatusLockWaitMs = 400
$script:StatusKeys = "^(q5_at|q5_pct|q7_at|q7_pct|q_at)"
$script:StatusChangesTag = "clm-"

function Get-StatusEntries {
  param([string]$Tag, $Usage)
  $r5 = Convert-ToEpoch $Usage.Reset5
  $r7 = Convert-ToEpoch $Usage.Reset7
  $values = @{ q_at = ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - [long]$Usage.Age) }
  if ($null -ne $r5) { $values["q5_at"] = $r5; $values["q5_pct"] = [int]$Usage.Pct5 }
  if ($null -ne $r7) { $values["q7_at"] = $r7; $values["q7_pct"] = [int]$Usage.Pct7 }
  return @(foreach ($k in "q5_at", "q5_pct", "q7_at", "q7_pct", "q_at") {
      if ($values.ContainsKey($k)) { $k + "@" + $Tag + " " + $values[$k] } else { $k + "@" + $Tag }
    })
}

function Write-StatusLines {
  param([string]$State, [string]$Tag, $Usage)
  $mine = $script:StatusKeys + "(@" + [regex]::Escape($Tag) + ")? "
  $applied = New-Object Collections.Generic.List[string]
  $lines = @(Merge-StatusChanges @(Read-StateFileLines $State) @(Get-StatusChanges $State) $applied)
  $keep = @($lines | Where-Object { $_ -cnotmatch $mine })
  $keep += @(Get-StatusEntries $Tag $Usage | Where-Object { $_.Contains(" ") })
  Write-TextFileAtomic $State (($keep -join "`n") + "`n")
  Remove-StatusChanges $applied.ToArray()
}

function Write-StatusFallback {
  param([string]$State, [string]$Tag, $Usage)
  Write-StatusChanges $State ($script:StatusChangesTag + $PID) @(Get-StatusEntries $Tag $Usage)
}

function Update-StatusState {
  param($Acc)
  $state = Get-StatusStatePath
  if (-not (Test-Path -LiteralPath (Split-Path $state))) { return }
  $u = Get-AccountUsage $Acc -NoRefresh
  if ($null -ne $u.Error) { return }
  $tag = Get-StateTag (Get-AccountPath $Acc)
  $lock = Open-MachineLock $script:StatusLockName $script:StatusLockWaitMs
  if ($null -eq $lock) { Write-StatusFallback $state $tag $u; return }
  try {
    $bar = Open-StatusStateLock $state $script:StatusStateLockWaitMs
    if ($null -eq $bar) { Write-StatusFallback $state $tag $u; return }
    try { Write-StatusLines $state $tag $u } catch { Write-StatusFallback $state $tag $u } finally { Close-StatusStateLock $bar }
  } finally { Close-MachineLock $lock }
}

if ($MyInvocation.InvocationName -ne ".") {
  try {
    $acc = Find-CurrentAccount
    if ($null -ne $acc) { Update-StatusState $acc }
  } catch { Write-Verbose $_.Exception.Message }
  exit 0
}
