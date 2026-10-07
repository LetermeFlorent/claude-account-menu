. (Join-Path $PSScriptRoot "claude-update-watch.ps1")
. (Join-Path $PSScriptRoot "claude-menu-progress.ps1")

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

function Show-UpdateTick {
  param($State, $Watch, [int]$Tick)
  $wait = Get-WaitBar $Tick
  $ver = "" + $State.Target
  if (-not $State.Mode) { Write-UpdateProgress "recherche de mise a jour" $wait "" ""; return }
  if ($Watch -eq $null -or -not $Watch.Seen) {
    $label = ("mise a jour " + $ver).Trim()
    Write-UpdateProgress $label $wait "" $State.Last
    return
  }
  if ($Watch.Settled) { Write-UpdateProgress ("installation " + $ver) (Get-ProgressBar 100) "100 %" ""; return }
  $p = Get-DownloadPercent $Watch.Bytes $Watch.Size
  $detail = Format-DownloadDetail $Watch.Bytes $Watch.Size
  if ($p -lt 0) { Write-UpdateProgress ("telechargement " + $ver) $wait "" $detail; return }
  Write-UpdateProgress ("telechargement " + $ver) (Get-ProgressBar $p) (("" + $p + " %").PadLeft(5)) $detail
}

function Invoke-ClaudeUpdate {
  param([string]$Exe, $Acc)
  $missing = New-Outcome "failed" "Claude Code introuvable, pas de mise a jour"
  if (-not $Exe -or -not (Test-Path -LiteralPath $Exe)) { return $missing }
  $proc = Invoke-InAccountEnv $Acc { Start-UpdateProcess $Exe }
  if ($proc -eq $null) { return $missing }
  $state = New-UpdateState
  $srcs = @((New-LineSource $proc.StandardOutput), (New-LineSource $proc.StandardError))
  $clock = [Diagnostics.Stopwatch]::StartNew()
  $watch = $null; $killed = ""; $exitAt = -1.0; $tick = 0
  try {
    while ($true) {
      foreach ($s in $srcs) { foreach ($l in Receive-Lines $s) { Add-UpdateLine $state $l } }
      if ($state.Mode -eq "native" -and $watch -eq $null) { $watch = New-StagingWatch $state.Target $proc.Id $clock.Elapsed.TotalSeconds }
      $now = $clock.Elapsed.TotalSeconds
      if ($watch -ne $null) { Update-StagingWatch $watch $now }
      if ($proc.HasExited) {
        if ($exitAt -lt 0) { $exitAt = $now }
        if (($srcs[0].Eof -and $srcs[1].Eof) -or $now - $exitAt -ge 2) { break }
      } else {
        $seen = $false; $settled = $false; $idle = 0.0
        if ($watch -ne $null) { $seen = $watch.Seen; $settled = $watch.Settled; $idle = $now - $watch.Changed }
        $killed = Get-WatchAction $now ([bool]($state.Mode -or $state.Done)) $seen $settled $idle
        if ($killed) { Stop-UpdateProcess $proc; break }
      }
      Show-UpdateTick $state $watch $tick
      $tick++
      Start-Sleep -Milliseconds 250
    }
  } finally {
    Write-Host ("`r" + (" " * ($script:ViewWidth - 1)) + "`r") -NoNewline
  }
  $code = -1
  if ($proc.HasExited) { $code = $proc.ExitCode }
  $proc.Dispose()
  return Get-UpdateOutcome $state $code $killed
}

function Get-AccountExe {
  param($Acc)
  return $script:ClaudeExe
}

function Get-UpdateGroups {
  param($Accounts)
  $groups = @(); $index = @{}
  foreach ($a in $Accounts) {
    $exe = "" + (Get-AccountExe $a)
    $key = ConvertTo-PathKey $exe
    if (-not $index.ContainsKey($key)) {
      $index[$key] = $groups.Count
      $groups += [PSCustomObject]@{ Exe = $exe; Accounts = @() }
    }
    $g = $groups[$index[$key]]
    $g.Accounts += $a
  }
  return $groups
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

function Update-ClaudeForAccounts {
  param($Accounts)
  $parts = @(); $kinds = @()
  foreach ($g in Get-UpdateGroups $Accounts) {
    $o = Invoke-ClaudeUpdate $g.Exe $g.Accounts[0]
    foreach ($a in $g.Accounts) { Write-Segs @(@(("  " + $a.Label + "  "), $script:Ink.Text, $true), @($o.Text, (Get-UpdateInk $o.Kind), $false)) }
    $parts += Format-UpdateMessage $g.Accounts $o.Text
    $kinds += $o.Kind
  }
  $kind = "ok"
  if ($kinds -contains "updated") { $kind = "updated" }
  if ($kinds -contains "failed") { $kind = "failed" }
  return @(($parts -join "   "), (Get-UpdateInk $kind))
}
