. (Join-Path $PSScriptRoot "startup-fakes.ps1")

try {
  New-StartupCase @("drive")
  $null = Invoke-StartupTicks
  $script:DriveJob.Loader = $null
  $script:DriveJob.Busy = $true
  $script:DriveJob.RetryAt = [long]::MaxValue
  $before = $script:DriveStarts
  $null = Invoke-StartupTicks 3
  Assert-Equal $before $script:DriveStarts "Drive occupe ailleurs : pas de relance avant l'heure du nouvel essai"
  Assert-Equal "run attente de la synchro en cours" ($script:Su.Steps[0].State + " " + $script:Su.Steps[0].Text) "Drive occupe ailleurs : attente affichee"
  $script:DriveJob.RetryAt = [long]0
  $null = Invoke-StartupTicks
  Assert-Equal ($before + 1) $script:DriveStarts "Drive occupe ailleurs : relance a l'heure du nouvel essai"
  $script:DriveJob.Loader = $null
  $script:DriveJob.RetryAt = [long]::MaxValue
  $script:T += 60000
  $null = Invoke-StartupTicks
  Assert-Equal "done ok laissee a un autre clm" ($script:Su.Steps[0].State + " " + $script:Su.Steps[0].Kind + " " + $script:Su.Steps[0].Text) "Drive occupe trop longtemps : synchro laissee a un autre clm"
} finally { Restore-StartupFakes }
