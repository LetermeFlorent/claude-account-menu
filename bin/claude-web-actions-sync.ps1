. Import-ClmModule claude-text
$script:WebPrefMoves = @{ on = "server.prefOn"; off = "server.prefOff"; erase = "server.prefErase" }

function Assert-WebDrive {
  if ($null -eq $script:DriveJob -or -not $script:DriveJob.Connected) { throw (Get-ClmText "server.driveOff") }
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
  if ($on) { return New-WebDone (Get-ClmText "server.autoOn") }
  return New-WebDone (Get-ClmText "server.autoOff")
}

function Invoke-WebDriveLogin {
  param($Data)
  if ($null -ne $script:DriveJob -and $script:DriveJob.Connected) { throw (Get-ClmText "server.driveOn") }
  return New-WebDone (Get-ClmText "server.driveLogin") $null @{ Name = "drivelogin" }
}

function Invoke-WebPcPref {
  param([string]$Pc, [string]$Id, [string]$Move)
  if ($Move -eq "erase") { throw (Get-ClmText "server.eraseHereOnly") }
  $webPcPrefs = Read-CliPrefs
  $webPcMe = Get-DrivePcName
  if ($null -eq $webPcPrefs.Catalog.Pcs -or $null -eq $webPcPrefs.Catalog.Pcs[$Pc]) { throw (Get-ClmText "server.unknownPc" $Pc) }
  if (-not (Test-PcReachable $webPcPrefs.Catalog $Pc)) { throw ($Pc + " : " + (Get-ClmText "sync.prefs.pc.old")) }
  $webPcItem = @(Resolve-PrefsItems (Get-PcPrefsLines $webPcPrefs.Choice $webPcPrefs.Catalog $webPcMe $Pc) @($Id))[0]
  $webPcName = $Pc
  $webPcOn = $Move -eq "on"
  $null = Update-SyncChoice { param($c) Set-PcPrefsCheck @{ Choice = $c; Catalog = $webPcPrefs.Catalog; Me = $webPcMe; Pc = $webPcName; Item = $webPcItem; On = $webPcOn } }
  $null = Request-DriveSync $script:DriveJob
  $key = "server.pcPrefOff"
  if ($webPcOn) { $key = "server.pcPrefOn" }
  return New-WebDone (Get-ClmText $key @($webPcItem.Label, $Pc)) (Get-WebPrefs)
}

function Invoke-WebPref {
  param($Data)
  $webMove = Get-WebText $Data "move"
  if (-not $script:WebPrefMoves.ContainsKey($webMove)) { throw (Get-ClmText "server.unknownMove" $webMove) }
  $webPc = Get-WebText $Data "pc"
  if ($webPc -and $webPc -cne (Get-DrivePcName)) { return Invoke-WebPcPref $webPc (Get-WebText $Data "id") $webMove }
  $webItem = @(Resolve-PrefsItems (Read-CliPrefs).Lines @(Get-WebText $Data "id"))[0]
  if ($webMove -eq "erase" -and $webItem.All) { throw (Get-ClmText "server.groupErase") }
  $null = Update-SyncChoice { param($c) Set-CliPrefsItem $c $webItem $webMove }
  $null = Request-DriveSync $script:DriveJob
  return New-WebDone (Get-ClmText $script:WebPrefMoves[$webMove] $webItem.Label) (Get-WebPrefs)
}

function Invoke-WebSave {
  param($Data)
  $webAccs = Find-WebAccounts @(Get-Accounts) (Get-WebList $Data "accs")
  $path = Invoke-WebWork "Sauvegarde" { Save-Accounts "" $webAccs }
  return New-WebDone (Get-ClmText "server.saved" $path) (Get-WebBackups)
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
