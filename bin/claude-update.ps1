if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-update-watch.ps1")) { . (Join-Path $PSScriptRoot "claude-update-watch.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-update-retry.ps1")) { . (Join-Path $PSScriptRoot "claude-update-retry.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-menu-progress.ps1")) { . (Join-Path $PSScriptRoot "claude-menu-progress.ps1") }

function Write-UpdateProgress {
  param([string]$Label, [string]$Bar, [string]$Pct, [string]$Detail)
  $head = "  " + $Label + "  "
  $mid = ""
  if ($Pct) { $mid = "  " + $Pct }
  $room = $script:ViewWidth - 3 - $head.Length - $Bar.Length - $mid.Length
  $tail = ""
  if ($Detail) { $tail = "  " + (Limit-Text $Detail ([math]::Max(4, $room))) }
  $pad = [math]::Max(0, $script:ViewWidth - 1 - $head.Length - $Bar.Length - $mid.Length - $tail.Length)
  $line = (Fg $script:Ink.Text) + $head + (Fg $script:Levels["7d"][0]) + $Bar + (Fg $script:Ink.Text) + $mid + (Fg $script:Ink.Dim) + $tail
  Write-Host ("`r" + $line + (" " * $pad) + $script:Esc + "[0m") -NoNewline
}

function Get-UpdateTick {
  param($State, $Watch)
  $ver = "" + $State.Target
  if (-not $State.Mode) {
    $label = "recherche de mise a jour"
    if ($State.Retry) { $label = $State.Retry }
    return @{ Label = $label; Pct = -1; Detail = "" }
  }
  if ($null -eq $Watch -or -not $Watch.Seen) { return @{ Label = ("mise a jour " + $ver).Trim(); Pct = -1; Detail = $State.Last } }
  if ($Watch.Settled) { return @{ Label = ("installation " + $ver); Pct = 100; Detail = "" } }
  return @{ Label = ("telechargement " + $ver); Pct = (Get-DownloadPercent $Watch.Bytes $Watch.Size); Detail = (Format-DownloadDetail $Watch.Bytes $Watch.Size) }
}

function Show-UpdateTick {
  param($State, $Watch, [int]$Tick)
  $t = Get-UpdateTick $State $Watch
  $bar = Get-WaitBar $Tick
  $pct = ""
  if ($t.Pct -ge 0) { $bar = Get-ProgressBar $t.Pct; $pct = ("" + $t.Pct + " %").PadLeft(5) }
  Write-UpdateProgress $t.Label $bar $pct $t.Detail
}

function Step-UpdateRun {
  param($Run, [double]$Now)
  if ($Run.Proc.HasExited) {
    if ($Run.ExitAt -lt 0) { $Run.ExitAt = $Now }
    return (($Run.Srcs[0].Eof -and $Run.Srcs[1].Eof) -or $Now - $Run.ExitAt -ge 2)
  }
  $seen = $false; $settled = $false; $idle = 0.0
  if ($null -ne $Run.Watch) { $seen = $Run.Watch.Seen; $settled = $Run.Watch.Settled; $idle = $Now - $Run.Watch.Changed }
  $Run.Killed = Get-WatchAction $Now ([bool]($Run.State.Mode -or $Run.State.Done)) $seen $settled $idle
  if ($Run.Killed) { Stop-UpdateProcess $Run.Proc; return $true }
  return $false
}

function Start-ClaudeUpdate {
  param([string]$Exe, $Acc)
  $proc = Start-ClaudeProcess $Exe $Acc
  if ($null -eq $proc) { return @{ Outcome = (New-Outcome "failed" $script:UpdateMissingText) } }
  return New-UpdateRun $proc $Exe $Acc
}

function Step-ClaudeUpdate {
  param($Run)
  if ($null -ne $Run.Outcome) { return $true }
  if ($Run.RetryAt -ge 0) { return Resume-UpdateTry $Run }
  foreach ($s in $Run.Srcs) { foreach ($l in Receive-Lines $s) { Add-UpdateLine $Run.State $l } }
  if ($Run.State.Mode -eq "native" -and $null -eq $Run.Watch) { $Run.Watch = New-StagingWatch $Run.State.Target $Run.Proc.Id $Run.Clock.Elapsed.TotalSeconds }
  $now = $Run.Clock.Elapsed.TotalSeconds
  if ($null -ne $Run.Watch) { Update-StagingWatch $Run.Watch $now }
  if (-not (Step-UpdateRun $Run $now)) { return $false }
  $code = -1
  if ($Run.Proc.HasExited) { $code = $Run.Proc.ExitCode }
  $Run.Proc.Dispose()
  $o = Get-UpdateOutcome $Run.State $code $Run.Killed
  if (Request-UpdateRetry $Run $o) { return $false }
  $Run.Outcome = $o
  return $true
}

function Invoke-ClaudeUpdate {
  param([string]$Exe, $Acc)
  $run = Start-ClaudeUpdate $Exe $Acc
  if ($null -ne $run.Outcome) { return $run.Outcome }
  $tick = 0
  try {
    while (-not (Step-ClaudeUpdate $run)) {
      Show-UpdateTick $run.State $run.Watch $tick
      $tick++
      Wait-Progress 250
    }
  } finally {
    Write-Host ("`r" + (" " * ($script:ViewWidth - 1)) + "`r") -NoNewline
  }
  return $run.Outcome
}

function Get-UpdateGroups {
  param($Accounts)
  if (@($Accounts).Count -eq 0) { return @() }
  return @([PSCustomObject]@{ Exe = "" + $script:ClaudeExe; Accounts = @($Accounts) })
}

function Format-UpdateMessage {
  param($Accounts, [string]$Text)
  return "  " + ((@($Accounts) | ForEach-Object { $_.Label }) -join ", ") + " : " + $Text
}

function Get-UpdateInk {
  param([string]$Kind)
  if ($Kind -eq "failed") { return $script:Ink.Alert }
  if ($Kind -eq "updated") { return $script:Levels["7d"][0] }
  return $script:Ink.Dim
}

function Get-UpdateKind {
  param($Kinds)
  if (@($Kinds) -contains "failed") { return "failed" }
  if (@($Kinds) -contains "updated") { return "updated" }
  return "ok"
}

function Get-UpdateSummary {
  param($Parts, $Kinds)
  return @((@($Parts) -join "   "), (Get-UpdateInk (Get-UpdateKind $Kinds)))
}

function Update-ClaudeForAccounts {
  param($Accounts)
  foreach ($g in Get-UpdateGroups $Accounts) {
    $o = Invoke-ClaudeUpdate $g.Exe $g.Accounts[0]
    foreach ($a in $g.Accounts) { Write-Segs @(@(("  " + $a.Label + "  "), $script:Ink.Text, $true), @($o.Text, (Get-UpdateInk $o.Kind), $false)) }
  }
}
