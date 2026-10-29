. Import-ClmModule claude-text, claude-menu-startup-steps, claude-menu-startup-claude, claude-menu-startup-clm, claude-menu-startup-fade
$script:ClmUpdated = $false
$script:ClmChecked = $false
$script:DriveChecked = $false
$script:Startup = $null
$script:StartupLabelKeys = @{ clm = "menu.startup.label.clm"; claude = "menu.startup.label.claude"; drive = "menu.startup.label.drive" }
$script:StartupFree = @("none", "refresh")
$script:StartupOpen = @("up", "down", "select", "drivesync", "web")
$script:StartupHiding = @("clm")
$script:StartupQuitWaits = @("clm", "claude")

function Get-StartupLabel {
  param([string]$Name)
  return Get-ClmText $script:StartupLabelKeys[$Name]
}

function New-StartupStep {
  param([string]$Name, [string]$After)
  $text = ""
  if ($After) { $text = Get-ClmText "menu.startup.after" @((Get-StartupLabel $After)) }
  return @{ Name = $Name; After = $After; Label = (Get-StartupLabel $Name); State = "wait"; Pct = -1; Text = $text; Kind = ""; Bar = (New-Tween 0 0 0 0); Work = $null; HideAt = $null; Fade = $null; Gone = $false }
}

function Close-StartupLock {
  Close-ClmStepLock
  Close-ClaudeStepLock
}

function Close-Startup {
  $script:Startup = $null
  Close-StartupLock
}

function New-Startup {
  param($Names)
  Close-StartupLock
  $steps = New-Object 'System.Collections.Generic.List[object]'
  foreach ($n in @($Names)) {
    $after = ""
    if ($n -ne "clm" -and @($Names) -contains "clm") { $after = "clm" }
    $steps.Add((New-StartupStep $n $after))
  }
  return @{ Steps = $steps; Quit = $false; Exit = $null; Pending = $null; Hidden = ($steps.Count -eq 0); ClmError = "" }
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
  $names = @(Get-StartupNames $Update $SelfUpdate)
  $script:Startup = New-Startup $names
  if ($names -contains "drive") { Start-DriveJob $script:DriveJob -Hold }
  $script:MenuState = New-MenuState @(Get-Accounts) $now
  Start-MenuLoader $script:MenuState
}

function Test-StepsLeft {
  param($Su, [string[]]$Names)
  if ($null -eq $Su) { return $false }
  foreach ($s in $Su.Steps) { if ($s.State -ne "done" -and ($Names.Count -eq 0 -or $Names -contains $s.Name)) { return $true } }
  return $false
}

function Test-StartupBlocking {
  param($Su)
  return Test-StepsLeft $Su $script:StartupHiding
}

function Test-QuitWaits {
  param($Su)
  foreach ($s in $Su.Steps) { if ($s.State -eq "run" -and $script:StartupQuitWaits -contains $s.Name) { return $true } }
  return $false
}

function Test-StepReady {
  param($Su, $Step)
  if ($Step.State -ne "wait") { return $true }
  if ($Su.Quit) { return $false }
  foreach ($s in $Su.Steps) { if ($s.Name -eq $Step.After) { return $s.State -eq "done" } }
  return $true
}

function Step-Startup {
  param($Su, $State, [double]$Now)
  if ($null -eq $Su -or $Su.Hidden -or $null -ne $Su.Exit) { return $false }
  if (-not (Test-StepsLeft $Su @())) { return Step-StartupEnd $Su $Now }
  $changed = $false
  foreach ($step in $Su.Steps) {
    if ($step.State -eq "done" -or -not (Test-StepReady $Su $step)) { continue }
    if (Invoke-StartupWork $Su $step $State $Now) { $changed = $true }
    if ($step.State -ne "done") { continue }
    if ($step.Kind -eq "failed" -and -not (Test-Network)) { $Su.Exit = @{ Name = "offline" } }
    if ($null -ne $Su.Exit) { return $true }
  }
  Set-StartupExit $Su
  if (Update-StepFades $Su $Now) { $changed = $true }
  return $changed -or $null -ne $Su.Exit
}

function Set-StartupExit {
  param($Su)
  if ($null -ne $Su.Exit) { return }
  if ($Su.Quit) { if (-not (Test-QuitWaits $Su)) { $Su.Exit = @{ Name = "quit" } }; return }
  if ($null -ne $Su.Pending -and -not (Test-StepsLeft $Su @())) { $Su.Exit = $Su.Pending }
}

function Get-HeldAction {
  param($State, [string]$Text)
  $State.Msg = @($Text, $script:Ink.Dim)
  $State.Dirty = $true
  return @{ Name = "none" }
}

function Get-StartupGate {
  param($Su, $Act, $State)
  if ($null -eq $Su) { return $Act }
  if ($null -ne $Su.Exit) { return $Su.Exit }
  if (-not (Test-StepsLeft $Su @()) -or $script:StartupFree -contains $Act.Name) { return $Act }
  if ($Act.Name -eq "quit") {
    if (-not (Test-QuitWaits $Su)) { return $Act }
    $Su.Quit = $true
    $Su.Pending = $null
    return Get-HeldAction $State ("  " + (Get-ClmText "menu.startup.stop_requested"))
  }
  if (Test-StartupBlocking $Su) { return Get-HeldAction $State ("  " + (Get-ClmText "menu.startup.accounts_after_clm_check")) }
  if ($script:StartupOpen -contains $Act.Name) { return $Act }
  if ($Act.Name -eq "launch") { $Act = @{ Name = "pick"; Index = $State.Sel } }
  if ($Act.Name -ne "pick") { return Get-HeldAction $State ("  " + (Get-ClmText "menu.startup.available_after_updates")) }
  $Su.Pending = $Act
  return Get-HeldAction $State ("  " + (Get-ClmText "menu.startup.launch_after_updates" @($State.Entries[$Act.Index].Acc.Label)))
}

function Add-ClmFailure {
  param($Msg, [string]$Err)
  if (-not $Err) { return $Msg }
  return @(("  " + (Get-ClmText "menu.startup.clm_update_failed" @($Err)) + "   " + ([string]$Msg[0]).Trim()).TrimEnd(), $script:Ink.Alert)
}
