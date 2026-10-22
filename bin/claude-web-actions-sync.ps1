$script:WebPrefMoves = @{ on = "synchronise sur ce PC"; off = "n'est plus synchronise sur ce PC"; erase = "efface partout a la prochaine synchro" }

function Assert-WebDrive {
  if ($null -eq $script:DriveJob -or -not $script:DriveJob.Connected) { throw "Drive non connecte" }
}

function Invoke-WebDriveSync {
  param($Data)
  Assert-WebDrive
  return New-WebDone ([string](Request-DriveSync $script:DriveJob)[0]).Trim()
}

function Invoke-WebDriveAuto {
  param($Data)
  Assert-WebDrive
  $on = $Data["on"] -eq $true
  Set-DriveAuto $on
  if ($on) { return New-WebDone "synchro automatique activee" }
  return New-WebDone "synchro automatique coupee"
}

function Invoke-WebDriveLogin {
  param($Data)
  if ($null -ne $script:DriveJob -and $script:DriveJob.Connected) { throw "Drive deja connecte" }
  return New-WebDone "connexion Google dans le navigateur, le terminal attend la reponse" $null @{ Name = "drivelogin" }
}

function Invoke-WebPcPref {
  param([string]$Pc, [string]$Id, [string]$Move)
  if ($Move -eq "erase") { throw "effacer partout se fait depuis les reglages de ce PC" }
  $webPcPrefs = Read-CliPrefs
  $webPcMe = Get-DrivePcName
  if ($null -eq $webPcPrefs.Catalog.Pcs -or $null -eq $webPcPrefs.Catalog.Pcs[$Pc]) { throw ("PC inconnu : " + $Pc) }
  if (-not (Test-PcReachable $webPcPrefs.Catalog $Pc)) { throw ($Pc + " : " + $script:PrefsPcOld) }
  $webPcItem = @(Resolve-PrefsItems (Get-PcPrefsLines $webPcPrefs.Choice $webPcPrefs.Catalog $webPcMe $Pc) @($Id))[0]
  $webPcName = $Pc
  $webPcOn = $Move -eq "on"
  $null = Update-SyncChoice { param($c) Set-PcPrefsCheck $c $webPcPrefs.Catalog $webPcMe $webPcName $webPcItem $webPcOn }
  $null = Request-DriveSync $script:DriveJob
  $text = " ne sera plus synchronise sur " + $Pc
  if ($webPcOn) { $text = " sera synchronise sur " + $Pc }
  return New-WebDone ($webPcItem.Label + $text + " a sa prochaine synchro") (Get-WebPrefs)
}

function Invoke-WebPref {
  param($Data)
  $webMove = Get-WebText $Data "move"
  if (-not $script:WebPrefMoves.ContainsKey($webMove)) { throw ("choix inconnu : " + $webMove) }
  $webPc = Get-WebText $Data "pc"
  if ($webPc -and $webPc -cne (Get-DrivePcName)) { return Invoke-WebPcPref $webPc (Get-WebText $Data "id") $webMove }
  $webItem = @(Resolve-PrefsItems (Read-CliPrefs).Lines @(Get-WebText $Data "id"))[0]
  if ($webMove -eq "erase" -and $webItem.All) { throw "un groupe entier ne s'efface pas" }
  $null = Update-SyncChoice { param($c) Set-CliPrefsItem $c $webItem $webMove }
  $null = Request-DriveSync $script:DriveJob
  return New-WebDone ($webItem.Label + " " + $script:WebPrefMoves[$webMove]) (Get-WebPrefs)
}

function Invoke-WebDisplay {
  param($Data)
  $cur = Read-DisplayConfig
  $p = Get-WebText $Data "palette"
  $a = Get-WebText $Data "anim"
  if (-not $p) { $p = $cur.palette }
  if (-not $a) { $a = $cur.anim }
  $null = Save-DisplayConfig $p $a
  Update-UiDisplay
  $script:MenuState.Dirty = $true
  return New-WebDone "affichage enregistre"
}

function Invoke-WebSave {
  param($Data)
  $webAccs = Find-WebAccounts @(Get-Accounts) (Get-WebList $Data "accs")
  $path = Invoke-WebWork "Sauvegarde" { Save-Accounts "" $webAccs }
  return New-WebDone ("sauvegarde : " + $path) (Get-WebBackups)
}

function Invoke-WebBackupsOf {
  param($Data)
  return New-WebDone "" @(Get-WebBackupAccounts (Get-WebText $Data "name"))
}

function Invoke-WebRestore {
  param($Data)
  $webZip = Find-WebBackup (Get-WebText $Data "name")
  Assert-BackupVersion $webZip
  $webAccs = Find-WebAccounts @(Get-ZipAccounts $webZip) (Get-WebList $Data "accs")
  $msg = Update-WebAccounts { Restore-Accounts $webZip $webAccs } "Restauration"
  return New-WebDone $msg (Get-WebBackups)
}
