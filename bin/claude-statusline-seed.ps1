. (Join-Path $PSScriptRoot "claude-usage.ps1")

function Convert-ToEpoch {
  param([string]$Iso)
  if ([string]::IsNullOrEmpty($Iso)) { return $null }
  try { return [DateTimeOffset]::Parse($Iso).ToUnixTimeSeconds() } catch { return $null }
}

function Find-CurrentAccount {
  $dir = $env:CLAUDE_CONFIG_DIR
  if ([string]::IsNullOrEmpty($dir)) { $dir = Join-Path $env:USERPROFILE ".claude" }
  $want = $dir.Replace("/", "\").TrimEnd("\").ToLower()
  foreach ($a in Get-Accounts) {
    if ((Get-AccountPath $a).Replace("/", "\").TrimEnd("\").ToLower() -eq $want) { return $a }
  }
  return $null
}

function Update-StatusState {
  param($Acc)
  $state = Join-Path $env:LOCALAPPDATA "claude-statusline\state"
  if (-not (Test-Path -LiteralPath (Split-Path $state))) { return }
  $u = Get-CompteUsage $Acc
  if ($u.Error -ne $null) { return }
  $keep = @()
  if (Test-Path -LiteralPath $state) {
    $keep = @(Get-Content -LiteralPath $state | Where-Object { $_ -notmatch "^(q5_at|q5_pct|q7_at|q7_pct|q_at) " })
  }
  $r5 = Convert-ToEpoch $u.Reset5
  $r7 = Convert-ToEpoch $u.Reset7
  if ($r5 -ne $null) { $keep += "q5_at " + $r5; $keep += "q5_pct " + [int]$u.Pct5 }
  if ($r7 -ne $null) { $keep += "q7_at " + $r7; $keep += "q7_pct " + [int]$u.Pct7 }
  $keep += "q_at " + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  [IO.File]::WriteAllText($state, (($keep -join "`n") + "`n"), (New-Object Text.UTF8Encoding($false)))
}

if ($MyInvocation.InvocationName -ne ".") {
  try {
    $acc = Find-CurrentAccount
    if ($acc -ne $null) { Update-StatusState $acc }
  } catch {}
  exit 0
}
