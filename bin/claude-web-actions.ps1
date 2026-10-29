. Import-ClmModule claude-web-actions-sync, claude-web-errors
$script:WebFree = @("backups-of")
$script:WebStartupText = "clm finit de demarrer, reessayer dans un instant"
$script:WebHandlers = @{
  refresh = "Invoke-WebRefresh"; rename = "Invoke-WebRename"; move = "Invoke-WebMove"; remove = "Invoke-WebRemove"; add = "Invoke-WebAdd"
  drivesync = "Invoke-WebDriveSync"; driveauto = "Invoke-WebDriveAuto"; drivelogin = "Invoke-WebDriveLogin"; pref = "Invoke-WebPref"
  display = "Invoke-WebDisplay"; save = "Invoke-WebSave"; "backups-of" = "Invoke-WebBackupsOf"; restore = "Invoke-WebRestore"; selfupdate = "Invoke-WebSelfUpdate"
}

function Get-WebText {
  param($Data, [string]$Name)
  if (@($Data.Keys) -cnotcontains $Name -or $null -eq $Data[$Name]) { return "" }
  return [string]$Data[$Name]
}

function Get-WebList {
  param($Data, [string]$Name)
  if (@($Data.Keys) -cnotcontains $Name -or $null -eq $Data[$Name]) { return ,[string[]]@() }
  return ,[string[]]@($Data[$Name] | ForEach-Object { [string]$_ })
}

function New-WebDone {
  param([string]$Msg, $Data = $null, $Next = $null)
  return @{ ok = $true; msg = $Msg; data = $Data; next = $Next }
}

function Find-WebAccount {
  param([string]$Dir)
  $hit = @(Get-Accounts | Where-Object { $_.Dir -ceq $Dir })
  if ($hit.Count -eq 0) { throw ("compte inconnu : " + $Dir) }
  return $hit[0]
}

function Find-WebAccounts {
  param($Accs, [string[]]$Dirs)
  if ($Dirs.Count -eq 0) { throw "aucun compte choisi" }
  foreach ($d in $Dirs) { if (@($Accs | Where-Object { $_.Dir -ceq $d }).Count -eq 0) { throw ("compte inconnu : " + $d) } }
  return @($Accs | Where-Object { $Dirs -ccontains $_.Dir })
}

function Invoke-WebWork {
  param([string]$Title, [scriptblock]$Job)
  Hide-Screen
  try { return Invoke-UiWork $Title ($Title + " demandee depuis la page web...") $Job } finally { if (-not $script:UiQuit) { Hide-Screen } }
}

function Update-WebAccounts {
  param([scriptblock]$Change, [string]$Title = "")
  Stop-MenuLoader 30000
  $keep = $script:MenuState.Sel
  try {
    if ($Title) { return Invoke-WebWork $Title $Change }
    return (& $Change)
  } finally { Reset-MenuState @("", $script:Ink.Dim) $keep }
}

function Invoke-WebRefresh {
  param($Data)
  $dir = Get-WebText $Data "acc"
  $st = $script:MenuState
  for ($i = 0; $i -lt $st.Entries.Count; $i++) {
    if ($st.Entries[$i].Acc.Dir -ceq $dir) { Request-EntryRead $st (Get-NowMs) 0 $i; return New-WebDone ([string]$st.Msg[0]).Trim() }
  }
  throw ("compte inconnu : " + $dir)
}

function Invoke-WebRename {
  param($Data)
  $webAcc = Find-WebAccount (Get-WebText $Data "acc")
  $webName = Get-WebText $Data "name"
  return New-WebDone (Update-WebAccounts { Rename-Account $webAcc $webName })
}

function Invoke-WebMove {
  param($Data)
  $webAcc = Find-WebAccount (Get-WebText $Data "acc")
  $rank = Get-WebText $Data "rank"
  if ($rank -notmatch '^[0-9]{1,4}$') { throw "rang illisible" }
  $webRank = [int]$rank
  return New-WebDone (Update-WebAccounts { Move-Account $webAcc $webRank })
}

function Invoke-WebRemove {
  param($Data)
  $webAcc = Find-WebAccount (Get-WebText $Data "acc")
  $webErase = $Data["erase"] -eq $true
  $title = ""
  if ($webErase) { $title = "Retrait de " + $webAcc.Label }
  return New-WebDone (Update-WebAccounts { Remove-Account $webAcc $webErase } $title)
}

function Invoke-WebAdd {
  param($Data)
  $name = (Get-WebText $Data "name").Trim()
  if ($name) { Assert-AccountName $name "" @(Get-Accounts) }
  return New-WebDone "ajout du compte : suivre la connexion dans le terminal" $null @{ Name = "add"; Arg = $name }
}

function Invoke-WebSelfUpdate {
  param($Data)
  if (-not (Test-ClmUpdateReady)) { throw "aucune mise a jour de clm en attente" }
  return New-WebDone "clm se met a jour et redemarre, la page va se fermer" $null @{ Name = "selfupdate" }
}

function Invoke-WebAction {
  param($Item)
  $name = Get-WebText $Item.Args "do"
  if ($null -ne $script:Startup -and (Test-StepsLeft $script:Startup @()) -and $script:WebFree -notcontains $name) {
    Send-WebJson $Item.Conn 409 @{ ok = $false; msg = $script:WebStartupText }
    return @{ Name = "none" }
  }
  try {
    if (-not $script:WebHandlers.ContainsKey($name)) { throw ("action inconnue : " + $name) }
    $r = & $script:WebHandlers[$name] $Item.Args
  } catch {
    $text = Get-WebErrorText $_ "W3"
    $r = @{ ok = $false; msg = $text; data = $null; next = $null; told = ($text -cne $_.Exception.Message) }
  }
  if ($null -ne $script:MenuState -and $r.msg -and -not $r.told -and $name -ne "backups-of") { Set-WebMenuMsg $r.msg (-not $r.ok) }
  Send-WebJson $Item.Conn 200 ([ordered]@{ ok = $r.ok; msg = $r.msg; data = $r.data })
  if ($null -eq $r.next) { return @{ Name = "none" } }
  return $r.next
}

function Set-WebMenuMsg {
  param([string]$Text, [bool]$Failed)
  $ink = $script:Levels["7d"][0]
  if ($Failed) { $ink = $script:Ink.Alert }
  $script:MenuState.Msg = @(("  " + $Text), $ink)
  $script:MenuState.Dirty = $true
}
