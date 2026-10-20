$script:MenuState = $null
$script:MenuUpdated = $false
$script:MenuRestart = $false
$script:MenuFails = @{ save = "  sauvegarde impossible : "; restore = "  restauration impossible : "; add = "  ajout impossible : "; remove = "  retrait impossible : "; rename = "  renommage impossible : "; drivelogin = "  connexion Drive impossible : " }

function Step-MenuFrame {
  $now = Get-NowMs
  $st = $script:MenuState
  Step-MenuLoader $st $now
  if (Update-UiTick $now $st.Busy) { $st.Dirty = $true }
  if (Update-MenuTimers $st $now) { $st.Dirty = $true }
  if (Step-ClmCheck $script:ClmCheck $now) { $st.Dirty = $true }
  if (Step-DriveJob $script:DriveJob) { Show-DriveNotice $st }
  if (Step-Startup $script:Startup $st $now) { $st.Dirty = $true }
  if ($st.Dirty -or (Test-MenuAnimating $st $now)) { Show-Menu $st $now; return $true }
  return $false
}

function Show-DriveNotice {
  param($State)
  $State.Dirty = $true
  $job = $script:DriveJob
  if ($null -eq $job.Notice) { return }
  $ink = $script:Levels["7d"][0]
  if ($job.Failed) { $ink = $script:Ink.Alert }
  $State.Msg = @(("  " + $job.Notice), $ink)
  $job.Notice = $null
}

function Stop-MenuLoader {
  param([int]$TimeoutMs)
  $st = $script:MenuState
  $st.Busy = $true
  Stop-UsageLoader $st.Loader $TimeoutMs {
    param($Ms)
    if ($Ms -ge 250) { $script:MenuState.Msg = @("  fin de la lecture en cours...", $script:Ink.Dim); $script:MenuState.Dirty = $true }
    $null = Step-MenuFrame
  }
  $st.Loader = $null
}

function Close-AccountMenu {
  param($Idx)
  $script:Startup = $null
  Stop-MenuLoader 1000
  Stop-ClmCheck
  if ($null -eq $Idx) { Stop-DriveJob $script:DriveJob }
  Hide-Screen
  Exit-UiScreen
  if ($null -eq $Idx) { return $null }
  return $script:MenuState.Entries[$Idx].Acc
}

function Invoke-MenuPage {
  param([string]$Name, [int]$Sel)
  if ($Name -eq "save") { return Show-SaveMenu }
  if ($Name -eq "restore") { return Show-RestoreMenu }
  if ($Name -eq "remove") { return Show-RemoveMenu $Sel }
  if ($Name -eq "rename") { return Show-RenameMenu $Sel }
  if ($Name -eq "drivelogin") { return Connect-MenuDrive }
  Exit-UiScreen
  try { return Add-Account } finally { Enter-UiScreen }
}

function Connect-MenuDrive {
  Exit-UiScreen
  try { $msg = Invoke-DriveLogin } finally { Enter-UiScreen }
  $script:DriveJob = $null
  Open-DriveJob
  $null = Request-DriveSync $script:DriveJob
  $script:DriveJob.Notify = $true
  return $msg
}

function Invoke-MenuCommand {
  param([string]$Name)
  Stop-MenuLoader 30000
  $sel = $script:MenuState.Sel
  Hide-Screen
  try { $msg = @(("  " + (Invoke-MenuPage $Name $sel)), $script:Levels["7d"][0]) }
  catch { $msg = @(($script:MenuFails[$Name] + $_.Exception.Message), $script:Ink.Alert) }
  if (-not $script:UiQuit) { Hide-Screen }
  $accs = @(Get-Accounts)
  $st = New-MenuState $accs (Get-NowMs) $false ([math]::Min($sel, $accs.Count - 1))
  $st.Msg = $msg
  $script:MenuState = $st
  Start-MenuLoader $st
}

function Read-MenuAction {
  param($State)
  $k = Read-UiKey
  $act = @{ Name = "none" }
  if ($k -is [hashtable]) { $act = Get-MenuMouseAction $State $k }
  elseif ($null -ne $k) { $act = Get-MenuAction $k $State.Entries.Count }
  if ($script:UiQuit) { $act = @{ Name = "quit" } }
  return $act
}

function Invoke-AccountMenu {
  param([bool]$Update, [bool]$SelfUpdate = $false)
  $script:UiQuit = $false
  $script:MenuRestart = $false
  $script:MenuOffline = $false
  $script:ClmUpdated = $false
  Enter-UiScreen
  Open-MenuSession $Update $SelfUpdate
  while ($true) {
    $st = $script:MenuState
    $n = $st.Entries.Count
    $act = Get-StartupGate $script:Startup (Read-MenuAction $st) $st
    $now = Get-NowMs
    if ($act.Name -eq "up") { Move-MenuSel $st (($st.Sel + $n - 1) % $n) $now $true }
    elseif ($act.Name -eq "down") { Move-MenuSel $st (($st.Sel + 1) % $n) $now $true }
    elseif ($act.Name -eq "select") { Move-MenuSel $st $act.Index $now $true }
    elseif ($act.Name -eq "launch") { return Close-AccountMenu $st.Sel }
    elseif ($act.Name -eq "pick") { return Close-AccountMenu $act.Index }
    elseif ($act.Name -eq "quit" -or $act.Name -eq "restart") { return Close-AccountMenu $null }
    elseif ($act.Name -eq "offline") { $script:MenuOffline = $true; return Close-AccountMenu $null }
    elseif ($act.Name -eq "refresh") { Request-EntryRead $st $now }
    elseif ($act.Name -eq "drivesync" -and -not $script:DriveJob.Connected) { Invoke-MenuCommand "drivelogin" }
    elseif ($act.Name -eq "drivesync") { $st.Msg = Request-DriveSync $script:DriveJob; $st.Dirty = $true }
    elseif ($act.Name -eq "selfupdate") {
      if (Test-ClmUpdateReady) { $script:MenuRestart = $true; return Close-AccountMenu $null }
      $st.Msg = @("  aucune mise a jour de clm en attente", $script:Ink.Dim); $st.Dirty = $true
    }
    elseif ($act.Name -ne "none") { Invoke-MenuCommand $act.Name }
    if (Step-MenuFrame) { Start-Sleep -Milliseconds 33 } else { Start-Sleep -Milliseconds 50 }
  }
}
