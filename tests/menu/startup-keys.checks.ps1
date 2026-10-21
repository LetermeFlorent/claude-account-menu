. (Join-Path $PSScriptRoot "startup-fakes.ps1")

try {
  New-StartupCase @("clm", "claude", "drive")
  $script:FakeLatest = $script:FakeV62
  $null = Invoke-StartupTicks
  Assert-Equal "none" (Send-StartupAct "quit").Name "Echap pendant la mise a jour : menu garde"
  Assert-Equal "  arret demande, fin de la mise a jour en cours..." $script:St.Msg[0] "Echap pendant la mise a jour : attente annoncee"
  $script:Work.Ctl.Done = $true
  $null = Invoke-StartupTicks 2
  Assert-Equal "Find-ClmUpdate v62 disponible, pas installee" (($script:Loads -join "|") + " " + $script:Su.Steps[0].Text) "Echap pendant la recherche : version annoncee, rien installe"
  Assert-Equal "quit" (Send-StartupAct "none").Name "Echap pendant la recherche : sortie a la fin de clm"
  Assert-Equal 0 ($script:ClaudeStarts + $script:DriveStarts) "Echap pendant la recherche : ni Claude Code ni Drive"

  New-StartupCase @("clm", "claude")
  $null = Invoke-StartupTicks; $script:Work.Ctl.Done = $true
  $null = Invoke-StartupTicks
  $null = Send-StartupAct "quit"
  $script:Work.Ctl.Done = $true
  $null = Invoke-StartupTicks 2
  Assert-Equal "v62 installee quit" ($script:Su.Steps[0].Text + " " + $script:Su.Exit.Name) "Echap pendant l'installation : installation finie puis sortie"
  Assert-True (-not $script:ClmUpdated) "Echap pendant l'installation : pas de redemarrage"
  $script:FakeLatest = $null

  New-StartupCase @("claude", "drive")
  $null = Invoke-StartupTicks 2
  $null = Send-StartupAct "quit"
  $null = Invoke-StartupTicks 3
  Assert-Equal "quit 1 0" ($script:Su.Exit.Name + " " + $script:ClaudeStarts + " " + $script:DriveStarts) "Echap pendant Claude Code : mise a jour finie, synchro pas lancee"

  New-StartupCase @("claude", "drive")
  Assert-Equal "none none none none" ((Send-StartupAct "save").Name + " " + (Send-StartupAct "launch").Name + " " + (Send-StartupAct "pick" 1).Name + " " + (Send-StartupAct "up").Name) "pendant la mise a jour : aucun compte ni commande"
  Assert-Equal "  comptes affiches a la fin des mises a jour" $script:St.Msg[0] "pendant la mise a jour : raison affichee"
  Assert-Equal "refresh" (Send-StartupAct "refresh").Name "relecture des quotas pendant la mise a jour"
  $script:Su.Index = 1
  Assert-Equal "none" (Send-StartupAct "launch").Name "pendant la synchro Drive : compte refuse"
  $script:Su.Index = 2
  Assert-Equal "save launch" ((Send-StartupAct "save").Name + " " + (Send-StartupAct "launch").Name) "tout a jour : menu libre"
  Assert-Equal "save" (Get-StartupGate $null @{ Name = "save" } $script:St).Name "sans bloc de lancement : menu libre"

  New-StartupCase @("drive", "claude")
  $null = Invoke-StartupTicks
  $script:DriveJob.Loader = $null
  $script:DriveJob.Failed = $true
  $script:FakeOnline = $true
  $null = Invoke-StartupTicks
  Assert-True ($null -eq $script:Su.Exit -and $script:Su.Index -eq 1) "echec avec internet : on continue"
  New-StartupCase @("drive", "claude")
  $null = Invoke-StartupTicks
  $script:DriveJob.Loader = $null
  $script:DriveJob.Failed = $true
  $script:FakeOnline = $false
  $null = Invoke-StartupTicks
  Assert-Equal "offline" $script:Su.Exit.Name "echec sans internet : clm se ferme"
  $script:FakeOnline = $true

  New-StartupCase @("drive")
  $null = Invoke-StartupTicks
  $script:DriveJob.Loader = $null
  $script:DriveJob.Failed = $true
  $null = Invoke-StartupTicks
  Assert-Equal "failed erreur" ($script:Su.Steps[0].Kind + " " + $script:Su.Steps[0].Text) "Drive : erreur"

  New-StartupCase @("drive")
  $null = Invoke-StartupTicks
  $script:DriveJob.Loader = $null
  $script:DriveJob.Busy = $true
  $null = Invoke-StartupTicks
  Assert-Equal "run attente de la synchro en cours 2" ($script:Su.Steps[0].State + " " + $script:Su.Steps[0].Text + " " + $script:DriveStarts) "Drive : synchro deja en cours, attente puis nouvel essai"
  Assert-Equal "none" (Send-StartupAct "launch").Name "Drive : compte refuse pendant l'attente"
  $script:DriveJob.Loader = $null
  $script:T += 60000
  $null = Invoke-StartupTicks
  Assert-Equal "ok en attente, une autre synchro tourne" ($script:Su.Steps[0].Kind + " " + $script:Su.Steps[0].Text) "Drive : attente trop longue, menu libre"

  Assert-Equal "  mise a jour de clm impossible : x" (Add-ClmFailure @("", $script:Ink.Dim) "x")[0] "erreur de clm sans autre message"
  Assert-Equal "  ok" (Add-ClmFailure @("  ok", $script:Ink.Dim) "")[0] "pas d'erreur de clm : message garde"
} finally { Restore-StartupFakes }
