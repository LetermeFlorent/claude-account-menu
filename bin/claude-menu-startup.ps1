. (Join-Path $PSScriptRoot "claude-menu-startup-steps.ps1")
$script:ClmUpdated = $false
$script:ClmChecked = $false
$script:Startup = $null
$script:StartupLabels = @{ clm = "clm"; claude = "Claude Code"; drive = "Drive" }
$script:StartupFree = @("none", "up", "down", "select", "refresh")
$script:StartupHoldMs = 1500
$script:StartupFadeMs = 300

function New-StartupStep {
  param([string]$Name, [string]$After)
  $text = ""
  if ($After) { $text = "apres " + $script:StartupLabels[$After] }
  return @{ Name = $Name; Label = $script:StartupLabels[$Name]; State = "wait"; Pct = -1; Text = $text; Kind = ""; Bar = (New-Tween 0 0 0 0); Work = $null }
}

function New-Startup {
  param($Names)
  $steps = New-Object 'System.Collections.Generic.List[object]'
  $prev = ""
  foreach ($n in @($Names)) { $steps.Add((New-StartupStep $n $prev)); $prev = $n }
  return @{ Steps = $steps; Index = 0; Launch = -1; Quit = $false; Exit = $null; EndAt = $null; Fade = $null; Hidden = ($steps.Count -eq 0); ClmError = "" }
}

function Get-StartupNames {
  param([bool]$Update, [bool]$SelfUpdate)
  $names = @()
  if ($SelfUpdate -and (Test-ClmInstalledHere)) { $names += "clm" }
  if ($Update) { $names += "claude" }
  if (Test-DriveAuto) { $names += "drive" }
  return $names
}

function Open-MenuSession {
  param([bool]$Update, [bool]$SelfUpdate)
  $now = Get-NowMs
  $script:ClmCheck = New-ClmCheck $now (Test-ClmInstalledHere) (Read-ClmVersion)
  Open-DriveJob $false
  $script:Startup = New-Startup @(Get-StartupNames $Update $SelfUpdate)
  $script:MenuState = New-MenuState @(Get-Accounts) $now
  Start-MenuLoader $script:MenuState
}

function Test-StartupBlocking {
  param($Su)
  for ($i = $Su.Index; $i -lt $Su.Steps.Count; $i++) { if ($Su.Steps[$i].Name -ne "drive") { return $true } }
  return $false
}

function Step-Startup {
  param($Su, $State, [double]$Now)
  if ($null -eq $Su -or $Su.Hidden -or $null -ne $Su.Exit) { return $false }
  if ($Su.Index -ge $Su.Steps.Count) { return Step-StartupEnd $Su $Now }
  $step = $Su.Steps[$Su.Index]
  if ($step.State -eq "wait" -and $Su.Quit) { $Su.Exit = @{ Name = "quit" }; return $true }
  $changed = Invoke-StartupWork $Su $step $State $Now
  if ($step.State -ne "done") { return $changed }
  $Su.Index++
  Set-StartupExit $Su
  return $true
}

function Step-StartupEnd {
  param($Su, [double]$Now)
  if ($null -eq $Su.EndAt) { $Su.EndAt = $Now + $script:StartupHoldMs; return $false }
  if ($Now -lt $Su.EndAt) { return $false }
  if ($null -eq $Su.Fade) { $Su.Fade = New-Tween 1 0 $script:StartupFadeMs $Now; return $true }
  if (Test-TweenRunning $Su.Fade $Now) { return $false }
  $Su.Hidden = $true
  return $true
}

function Set-StartupExit {
  param($Su)
  if ($null -ne $Su.Exit -or (Test-StartupBlocking $Su)) { return }
  if ($Su.Quit) { $Su.Exit = @{ Name = "quit" }; return }
  if ($Su.Launch -lt 0) { return }
  if ($Su.Index -lt $Su.Steps.Count) { Start-DriveJob $script:DriveJob }
  $Su.Exit = @{ Name = "pick"; Index = $Su.Launch }
}

function Get-StartupGate {
  param($Su, $Act, $State)
  if ($null -eq $Su) { return $Act }
  if ($null -ne $Su.Exit) { return $Su.Exit }
  if (-not (Test-StartupBlocking $Su) -or $script:StartupFree -contains $Act.Name) { return $Act }
  if ($Act.Name -eq "launch" -or $Act.Name -eq "pick") { return Set-StartupLaunch $Su $Act $State }
  $text = "  disponible a la fin de la mise a jour"
  if ($Act.Name -eq "quit") {
    $Su.Quit = $true
    $Su.Launch = -1
    $text = "  arret demande, fin de la mise a jour en cours..."
  }
  $State.Msg = @($text, $script:Ink.Dim)
  $State.Dirty = $true
  return @{ Name = "none" }
}

function Set-StartupLaunch {
  param($Su, $Act, $State)
  $i = $State.Sel
  if ($Act.Name -eq "pick") { $i = $Act.Index }
  $Su.Launch = $i
  $Su.Quit = $false
  $State.Msg = @(("  " + $State.Entries[$i].Acc.Label + " : lancement a la fin de la mise a jour"), $script:Ink.Dim)
  $State.Dirty = $true
  return @{ Name = "select"; Index = $i }
}

function Add-ClmFailure {
  param($Msg, [string]$Err)
  if (-not $Err) { return $Msg }
  return @(("  mise a jour de clm impossible : " + $Err + "   " + ([string]$Msg[0]).Trim()).TrimEnd(), $script:Ink.Alert)
}
