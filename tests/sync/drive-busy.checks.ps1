$busyPass = (Get-Item "function:Set-SyncPassphrase").ScriptBlock
$busyConfig = $script:DriveConfigPath
$script:DriveConfigPath = Join-Path $script:Sandbox "drive-busy.json"
try {
  Assert-Equal (Get-ClmText "drive.sync.replaced") (Get-DriveBusyText) "synchro laissee a la version mise a jour : texte de la langue"
  Assert-True ((Get-DriveBusyText).Length -gt 0) "synchro laissee a la version mise a jour : texte non vide"
  Assert-True ((Get-DriveBusyText) -ne (Get-LeftToOtherClm)) "synchro laissee a la version mise a jour : texte distinct de l'autre clm"

  function Set-SyncPassphrase { throw (Get-LeftToOtherClm) }
  $busyOut = @(Invoke-DriveCli @{ Name = "key" } 6>&1 | ForEach-Object { "" + $_ })
  Assert-Equal (Get-ClmText "drive.passphrase.busy") $busyOut[0] "phrase de synchro, Drive occupe : texte propre"
  Assert-True ((Get-ClmText "drive.passphrase.busy") -ne (Get-LeftToOtherClm)) "phrase de synchro, Drive occupe : pas le texte de la synchro"
  Assert-Equal 1 ($busyOut | Select-Object -Last 1) "phrase de synchro, Drive occupe : echec"

  function Set-SyncPassphrase { throw "autre panne" }
  $busyOther = @(Invoke-DriveCli @{ Name = "key" } 6>&1 | ForEach-Object { "" + $_ })
  Assert-Equal "autre panne" $busyOther[0] "phrase de synchro, autre panne : message garde tel quel"
} finally {
  Set-Item "function:Set-SyncPassphrase" $busyPass
  $script:DriveConfigPath = $busyConfig
}
