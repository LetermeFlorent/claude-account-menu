. (Join-Path (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "menu") "startup-fakes.ps1")
$lockShaFn = (Get-Item "function:Get-ClmSha").ScriptBlock
$lockLoaded = $script:ClmLoadedSha
$lockWait = $script:ClmUpdateWaitMs
$script:LockDiskSha = ""
$script:LockShaFail = ""
function Get-ClmSha { param([string]$Dir = "") if ($script:LockShaFail) { throw $script:LockShaFail }; return $script:LockDiskSha }

try {
  $script:ClmLoadedSha = "a" * 40
  $script:LockDiskSha = "a" * 40
  New-StartupCase @("clm", "claude")
  $held = Open-MachineLock $script:ClmUpdateLock
  Assert-True ($null -ne $held) "verrou de mise a jour libre avant ces cas"
  try {
    $null = Invoke-StartupTicks 2
    Assert-Equal "" ($script:Loads -join "|") "autre clm en pleine mise a jour : pas de recherche en double"
    Assert-Equal ("lock|" + (Get-ClmText "update.startup.waitOther") + "|apres clm") ($script:Su.Steps[0].State + "|" + (Get-StepList "Text")) "autre clm en pleine mise a jour : attente affichee"
    Assert-True (Test-StartupBlocking $script:Su) "autre clm en pleine mise a jour : comptes caches"
    Assert-Equal "quit" (Send-StartupAct "quit").Name "autre clm en pleine mise a jour : arret sans attendre"
  } finally { Close-MachineLock $held }
  $script:LockDiskSha = "b" * 40
  $null = Invoke-StartupTicks
  Assert-Equal "" ($script:Loads -join "|") "nouvelle version posee par un autre clm : ni recherche ni installation"
  Assert-Equal ("updated " + (Get-ClmText "update.startup.withRestart" @((Get-ClmText "update.startup.byPeer")))) ($script:Su.Steps[0].Kind + " " + $script:Su.Steps[0].Text) "nouvelle version posee par un autre clm : redemarrage annonce"
  Assert-True ($script:ClmUpdated -and "restart" -eq $script:Su.Exit.Name) "nouvelle version posee par un autre clm : menu ferme pour redemarrer"
  $again = Open-MachineLock $script:ClmUpdateLock
  Assert-True ($null -ne $again) "nouvelle version posee par un autre clm : verrou rendu"
  Close-MachineLock $again

  $script:ClmLoadedSha = "b" * 40
  Write-ClmChecked
  New-StartupCase @("clm", "claude")
  $null = Invoke-StartupTicks
  Assert-Equal "" ($script:Loads -join "|") "clm verifie a l'instant par un autre clm : pas de recherche"
  Assert-Equal ("ok " + (Get-ClmText "update.startup.upToDate")) ($script:Su.Steps[0].Kind + " " + $script:Su.Steps[0].Text) "clm verifie a l'instant par un autre clm : a jour"
  Remove-Item -LiteralPath (Get-StatePath ($script:ClmCheckStamp + ".done")) -Force

  $script:ClmUpdateWaitMs = 1000
  New-StartupCase @("clm", "claude")
  $held = Open-MachineLock $script:ClmUpdateLock
  try { $null = Invoke-StartupTicks 6 } finally { Close-MachineLock $held }
  Assert-Equal ("ok " + (Get-ClmText "update.startup.leftToOther")) ($script:Su.Steps[0].Kind + " " + $script:Su.Steps[0].Text) "autre clm bloque trop longtemps : recherche laissee, sans erreur"
  Assert-Equal 1 $script:ClaudeStarts "autre clm bloque trop longtemps : Claude Code continue"

  $script:LockShaFail = "version illisible"
  New-StartupCase @("clm", "claude")
  Assert-Throws { Invoke-StartupTicks } "version illisible" "version de clm illisible : erreur remontee"
  $script:LockShaFail = ""
  $again = Open-MachineLock $script:ClmUpdateLock
  Assert-True ($null -ne $again) "version de clm illisible : verrou rendu"
  Close-MachineLock $again

  New-StartupCase @("clm", "claude")
  $null = Invoke-StartupTicks
  Assert-Equal "run" $script:Su.Steps[0].State "demarrage abandonne : recherche de clm en cours"
  New-StartupCase @("claude")
  $again = Open-MachineLock $script:ClmUpdateLock
  Assert-True ($null -ne $again) "demarrage abandonne : verrou rendu au demarrage suivant"
  Close-MachineLock $again

  New-StartupCase @("clm", "claude")
  $null = Invoke-StartupTicks
  $script:Startup = $script:Su
  Close-Startup
  $again = Open-MachineLock $script:ClmUpdateLock
  Assert-True ($null -eq $script:Startup -and $null -ne $again) "menu ferme pendant la recherche de clm : verrou rendu"
  Close-MachineLock $again
} finally {
  Set-Item -Path "function:script:Get-ClmSha" -Value $lockShaFn
  $script:ClmLoadedSha = $lockLoaded
  $script:ClmUpdateWaitMs = $lockWait
  Restore-StartupFakes
}
