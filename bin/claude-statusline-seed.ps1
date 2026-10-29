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

. Import-ClmModule claude-machine-lock
$script:StatusLockName = "statusline"
$script:StatusLockWaitMs = 5000
$script:StatusKeys = "^(q5_at|q5_pct|q7_at|q7_pct|q_at)"

function Read-StatusLines {
  param([string]$State)
  if (-not [IO.File]::Exists($State)) { return @() }
  $lines = @((Read-SharedText $State) -split "`r?`n")
  if ($lines[-1] -eq "") { $lines = @($lines | Select-Object -First ($lines.Count - 1)) }
  return $lines
}

function Write-StatusLines {
  param([string]$State, [string]$Tag, $Usage)
  $mine = $script:StatusKeys + "(@" + [regex]::Escape($Tag) + ")? "
  $keep = @(Read-StatusLines $State | Where-Object { $_ -cnotmatch $mine })
  $r5 = Convert-ToEpoch $Usage.Reset5
  $r7 = Convert-ToEpoch $Usage.Reset7
  $at = "@" + $Tag + " "
  if ($null -ne $r5) { $keep += "q5_at" + $at + $r5; $keep += "q5_pct" + $at + [int]$Usage.Pct5 }
  if ($null -ne $r7) { $keep += "q7_at" + $at + $r7; $keep += "q7_pct" + $at + [int]$Usage.Pct7 }
  $keep += "q_at" + $at + ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - [long]$Usage.Age)
  Write-TextFileAtomic $State (($keep -join "`n") + "`n")
}

function Update-StatusState {
  param($Acc)
  $state = Get-StatusStatePath
  if (-not (Test-Path -LiteralPath (Split-Path $state))) { return }
  $u = Get-AccountUsage $Acc -NoRefresh
  if ($null -ne $u.Error) { return }
  $tag = Get-StateTag (Get-AccountPath $Acc)
  $lock = Open-MachineLock $script:StatusLockName $script:StatusLockWaitMs
  if ($null -eq $lock) { return }
  try { Write-StatusLines $state $tag $u } finally { Close-MachineLock $lock }
}

if ($MyInvocation.InvocationName -ne ".") {
  try {
    $acc = Find-CurrentAccount
    if ($null -ne $acc) { Update-StatusState $acc }
  } catch { Write-Verbose $_.Exception.Message }
  exit 0
}
