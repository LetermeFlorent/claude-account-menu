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

function Update-StatusState {
  param($Acc)
  $state = Get-StatusStatePath
  if (-not (Test-Path -LiteralPath (Split-Path $state))) { return }
  $u = Get-AccountUsage $Acc -NoRefresh
  if ($null -ne $u.Error) { return }
  $tag = Get-StateTag (Get-AccountPath $Acc)
  $mine = "^(q5_at|q5_pct|q7_at|q7_pct|q_at)(@" + [regex]::Escape($tag) + ")? "
  $keep = @()
  if (Test-Path -LiteralPath $state) {
    $keep = @(Get-Content -LiteralPath $state | Where-Object { $_ -cnotmatch $mine })
  }
  $r5 = Convert-ToEpoch $u.Reset5
  $r7 = Convert-ToEpoch $u.Reset7
  $at = "@" + $tag + " "
  if ($null -ne $r5) { $keep += "q5_at" + $at + $r5; $keep += "q5_pct" + $at + [int]$u.Pct5 }
  if ($null -ne $r7) { $keep += "q7_at" + $at + $r7; $keep += "q7_pct" + $at + [int]$u.Pct7 }
  $keep += "q_at" + $at + ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - [long]$u.Age)
  Write-TextFileAtomic $state (($keep -join "`n") + "`n")
}

if ($MyInvocation.InvocationName -ne ".") {
  try {
    $acc = Find-CurrentAccount
    if ($null -ne $acc) { Update-StatusState $acc }
  } catch { Write-Verbose $_.Exception.Message }
  exit 0
}
