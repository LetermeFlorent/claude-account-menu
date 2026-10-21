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
  return $r
}

function Start-ClmWork {
  param($Step, [string]$Reader, $Item, [string]$Text, [double]$Now)
  $Step.Work = Start-UsageLoader @(, $Item) (Join-Path $PSScriptRoot "claude-self-update.ps1") $Reader
  $Step.Reader = $Reader
  $Step.State = "run"
  $null = Set-StartupProgress $Step -1 $Text $Now
}

function Complete-ClmFind {
  param($Su, $Step, $R, [double]$Now)
  if ($R.Error) { Complete-StartupStep $Step "failed" "recherche impossible" $Now; return }
  if ($null -eq $R.Value) { Complete-StartupStep $Step "ok" "a jour" $Now; return }
  $Step.Found = $R.Value
  if ($Su.Quit) { Complete-StartupStep $Step "ok" ((Get-ClmName $R.Value) + " disponible, pas installee") $Now; return }
  Start-ClmWork $Step "Install-ClmVersion" $R.Value ("installation " + (Format-ClmVersion $R.Value)) $Now
}

function Complete-ClmInstall {
  param($Su, $Step, $State, $R, [double]$Now)
  if ($R.Error) {
    $Su.ClmError = $R.Error
    $State.Msg = Add-ClmFailure @("", $script:Ink.Dim) $R.Error
    Complete-StartupStep $Step "failed" ("installation impossible : " + $R.Error) $Now
    return
  }
  $text = (Get-ClmName $Step.Found) + " installee"
  if (-not $Su.Quit) { $text += ", redemarrage"; $script:ClmUpdated = $true; $Su.Exit = @{ Name = "restart" } }
  Complete-StartupStep $Step "updated" $text $Now
}

function Step-ClmStartup {
  param($Su, $Step, $State, [double]$Now)
  if ($Step.State -eq "wait") {
    $script:ClmChecked = $true
    Start-ClmWork $Step "Find-ClmUpdate" 0 "recherche d'une nouvelle version" $Now
    return $true
  }
  $r = Receive-LoaderValue $Step.Work
  if ($null -eq $r) { return $false }
  if ($Step.Reader -eq "Find-ClmUpdate") { Complete-ClmFind $Su $Step $r $Now }
  else { Complete-ClmInstall $Su $Step $State $r $Now }
  return $true
}

function Step-ClaudeStartup {
  param($Su, $Step, $State, [double]$Now)
  if ($Step.State -eq "wait") {
    $Step.Groups = @(Get-UpdateGroups @(Get-Accounts))
    $Step.Group = 0; $Step.Run = $null; $Step.NextAt = $Now
    $Step.Parts = @(); $Step.Kinds = @(); $Step.Texts = @()
    $Step.State = "run"
    $script:MenuUpdated = $true
    $null = Set-StartupProgress $Step -1 "recherche de mise a jour" $Now
    return $true
  }
  if ($Now -lt $Step.NextAt) { return $false }
  $Step.NextAt = $Now + $script:StartupPollMs
  if ($null -ne $Step.Run -and -not (Step-ClaudeUpdate $Step.Run)) {
    $t = Get-UpdateTick $Step.Run.State $Step.Run.Watch
    return Set-StartupProgress $Step $t.Pct (($t.Label + "  " + $t.Detail).Trim()) $Now
  }
  if ($null -ne $Step.Run) { Add-ClaudeOutcome $Step }
  if ($Step.Group -lt $Step.Groups.Count) {
    $g = $Step.Groups[$Step.Group]
    $Step.Group++
    $Step.Run = Start-ClaudeUpdate $g.Exe $g.Accounts[0]
    return $false
  }
  $State.Msg = Add-ClmFailure (Get-UpdateSummary $Step.Parts $Step.Kinds) $Su.ClmError
  Complete-StartupStep $Step (Get-UpdateKind $Step.Kinds) ($Step.Texts -join ", ") $Now
  return $true
}

function Add-ClaudeOutcome {
  param($Step)
  $o = $Step.Run.Outcome
  $Step.Parts += Format-UpdateMessage $Step.Groups[$Step.Group - 1].Accounts $o.Text
  $Step.Kinds += $o.Kind
  $Step.Texts += ($o.Text -replace "^Claude Code ", "")
  $Step.Run = $null
}

function Step-DriveStartup {
  param($Step, [double]$Now)
  $job = $script:DriveJob
  if ($Step.State -eq "wait") {
    $script:DriveChecked = $true
    $Step.BusyEnd = $Now + $script:DriveStartupBusyMs
    Start-DriveJob $job
    $Step.State = "run"
    $null = Set-StartupProgress $Step -1 "preparation" $Now
    return $true
  }
  if (Test-DriveJobRunning $job) {
    $p = "" + $job.Ctl.Progress
    if ($p -match "^(\d+)/(\d+)$" -and [int]$Matches[2] -gt 0) { return Set-StartupProgress $Step ([int][math]::Floor([int]$Matches[1] * 100 / [int]$Matches[2])) ($p + " fichiers") $Now }
    return Set-StartupProgress $Step -1 "preparation" $Now
  }
  if ($job.Busy -and $Now -lt $Step.BusyEnd) {
    Start-DriveJob $job
    return Set-StartupProgress $Step -1 "attente de la synchro en cours" $Now
  }
  if ($job.Failed) { Complete-StartupStep $Step "failed" "erreur" $Now }
  elseif ($job.Busy) { Complete-StartupStep $Step "ok" "en attente, une autre synchro tourne" $Now }
  else { Complete-StartupStep $Step "ok" "a jour" $Now }
  return $true
}

function Invoke-StartupWork {
  param($Su, $Step, $State, [double]$Now)
  if ($Step.Name -eq "clm") { return Step-ClmStartup $Su $Step $State $Now }
  if ($Step.Name -eq "claude") { return Step-ClaudeStartup $Su $Step $State $Now }
  return Step-DriveStartup $Step $Now
}
