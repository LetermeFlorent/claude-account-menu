. Import-ClmModule claude-text
$script:StartupPollMs = 250
$script:StartupBarMs = 350
$script:DriveStartupBusyMs = 60000

function Set-StartupProgress {
  param($Step, [int]$Pct, [string]$Text, [double]$Now)
  $changed = $Pct -ne $Step.Pct -or $Text -ne $Step.Text
  if ($Pct -ge 0 -and $Pct -ne $Step.Pct) { Set-TweenTarget $Step.Bar $Pct $script:StartupBarMs $Now }
  $Step.Pct = $Pct
  $Step.Text = $Text
  return $changed
}

function Complete-StartupStep {
  param($Step, [string]$Kind, [string]$Text, [double]$Now)
  $null = Set-StartupProgress $Step 100 $Text $Now
  $Step.Kind = $Kind
  $Step.State = "done"
  $Step.Work = $null
}

function Receive-LoaderValue {
  param($Loader)
  if (-not $Loader.Ctl.Done) { return $null }
  $res = Receive-UsageResults $Loader
  Close-UsageLoader $Loader
  $r = @{ Value = $null; Error = ("" + $Loader.Ctl.Error) }
  if ($res.Count -gt 0) { $r.Value = $res[0][1]; if ($res[0][2]) { $r.Error = "" + $res[0][2] } }
  if ($Loader.Ctl.Replaced -eq $true) { $r.Error = Get-ClmText "menu.startup.loader_replaced" }
  return $r
}

function Step-DriveStartup {
  param($Step, [double]$Now)
  $job = $script:DriveJob
  if ($Step.State -eq "wait") {
    $script:DriveChecked = $true
    $Step.BusyEnd = $Now + $script:DriveStartupBusyMs
    Start-DriveJob $job
    $Step.State = "run"
    $null = Set-StartupProgress $Step -1 (Get-ClmText "menu.startup.preparing") $Now
    return $true
  }
  if (Test-DriveJobRunning $job) {
    $p = "" + $job.Ctl.Progress
    if ($p -match "^(\d+)/(\d+)$" -and [int]$Matches[2] -gt 0) { return Set-StartupProgress $Step ([int][math]::Floor([int]$Matches[1] * 100 / [int]$Matches[2])) (Get-ClmText "menu.startup.files" @($p)) $Now }
    return Set-StartupProgress $Step -1 (Get-ClmText "menu.startup.preparing") $Now
  }
  if ($job.Busy -and $Now -lt $Step.BusyEnd) {
    if ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() -ge $job.RetryAt) { Start-DriveJob $job }
    return Set-StartupProgress $Step -1 (Get-ClmText "menu.startup.waiting_sync") $Now
  }
  if ($job.Failed) { Complete-StartupStep $Step "failed" (Get-ClmText "menu.startup.error") $Now }
  elseif ($job.Busy) { Complete-StartupStep $Step "ok" (Get-ClmText "menu.startup.left_to_other_clm") $Now }
  else { Complete-StartupStep $Step "ok" (Get-ClmText "menu.startup.up_to_date") $Now }
  return $true
}

function Invoke-StartupWork {
  param($Su, $Step, $State, [double]$Now)
  if ($Step.Name -eq "clm") { return Step-ClmStartup $Su $Step $State $Now }
  if ($Step.Name -eq "claude") { return Step-ClaudeStartup $Su $Step $State $Now }
  return Step-DriveStartup $Step $Now
}
