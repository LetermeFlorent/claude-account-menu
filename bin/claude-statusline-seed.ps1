. (Join-Path $PSScriptRoot "claude-usage.ps1")

function Convert-ToEpoch {
  param($Iso)
  $at = ConvertTo-DateOffset $Iso
  if ($at -eq $null) { return $null }
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
  $u = Get-CompteUsage $Acc
  if ($u.Error -ne $null) { return }
  $tag = Get-StateTag (Get-AccountPath $Acc)
  $mine = "^(q5_at|q5_pct|q7_at|q7_pct|q_at)(@" + [regex]::Escape($tag) + ")? "
  $keep = @()
  if (Test-Path -LiteralPath $state) {
    $keep = @(Get-Content -LiteralPath $state | Where-Object { $_ -cnotmatch $mine })
  }
  $r5 = Convert-ToEpoch $u.Reset5
  $r7 = Convert-ToEpoch $u.Reset7
  $at = "@" + $tag + " "
  if ($r5 -ne $null) { $keep += "q5_at" + $at + $r5; $keep += "q5_pct" + $at + [int]$u.Pct5 }
  if ($r7 -ne $null) { $keep += "q7_at" + $at + $r7; $keep += "q7_pct" + $at + [int]$u.Pct7 }
  $keep += "q_at" + $at + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  [IO.File]::WriteAllText($state, (($keep -join "`n") + "`n"), (New-Object Text.UTF8Encoding($false)))
}

if ($MyInvocation.InvocationName -ne ".") {
  try {
    $acc = Find-CurrentAccount
    if ($acc -ne $null) { Update-StatusState $acc }
  } catch {}
  exit 0
}
