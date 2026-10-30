. (Join-Path $PSScriptRoot "startup-fakes.ps1")

try {
  New-StartupCase @("clm", "claude", "drive")
  $script:FakeLatest = $script:FakeV62
  $null = Invoke-StartupTicks
  Assert-Equal "none" (Send-StartupAct "quit").Name "Echap pendant la mise a jour : menu garde"
  Assert-Equal ("  " + (Get-ClmText "menu.startup.stop_requested")) $script:St.Msg[0] "Echap pendant la mise a jour : attente annoncee"
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
  $null = Invoke-StartupTicks
  Assert-True ($false -eq $script:Su.Steps[0].Run.CanRetry) "Echap pendant Claude Code : plus de nouvel essai"
  $null = Invoke-StartupTicks 2
  Assert-Equal "quit 1 1" ($script:Su.Exit.Name + " " + $script:ClaudeStarts + " " + $script:DriveStarts) "Echap pendant Claude Code : mise a jour finie, synchro arretee a la fermeture"

  New-StartupCase @("clm", "claude")
  $null = Invoke-StartupTicks
  Assert-Equal "none none" ((Send-StartupAct "launch").Name + " " + (Send-StartupAct "up").Name) "verification de clm : comptes caches"
  Assert-Equal ("  " + (Get-ClmText "menu.startup.accounts_after_clm_check")) $script:St.Msg[0] "verification de clm : raison affichee"
  Assert-Equal "refresh" (Send-StartupAct "refresh").Name "relecture des quotas pendant la verification"

  New-StartupCase @("claude", "drive")
  $null = Invoke-StartupTicks
  Assert-Equal "none" (Send-StartupAct "save").Name "pendant les mises a jour : commandes plus tard"
  Assert-Equal ("  " + (Get-ClmText "menu.startup.available_after_updates")) $script:St.Msg[0] "pendant les mises a jour : raison affichee"
  Assert-Equal "up select drivesync" ((Send-StartupAct "up").Name + " " + (Send-StartupAct "select" 2).Name + " " + (Send-StartupAct "drivesync").Name) "pendant les mises a jour : comptes accessibles"
  Assert-Equal "none" (Send-StartupAct "launch").Name "Entree pendant les mises a jour : lancement differe"
  Assert-Equal ("  " + (Get-ClmText "menu.startup.launch_after_updates" @("a"))) $script:St.Msg[0] "Entree pendant les mises a jour : attente annoncee"
  $null = Send-StartupAct "pick" 1
  Assert-Equal ("  " + (Get-ClmText "menu.startup.launch_after_updates" @("b"))) $script:St.Msg[0] "autre compte choisi : remplace le premier"
  $null = Invoke-StartupTicks 3
  Assert-Null $script:Su.Exit "Claude Code fini, Drive en cours : lancement encore differe"
  $script:DriveJob.Loader = $null
  $null = Invoke-StartupTicks
  Assert-Equal "pick 1" ($script:Su.Exit.Name + " " + $script:Su.Exit.Index) "mises a jour finies : compte lance"
  Assert-Equal "pick" (Send-StartupAct "save").Name "sortie decidee : rendue a chaque touche"

  New-StartupCase @("claude", "drive")
  $null = Invoke-StartupTicks 4
  Assert-Equal "quit" (Send-StartupAct "quit").Name "Echap pendant la seule synchro Drive : sortie tout de suite"
  $script:Su.Steps[0].State = "done"; $script:Su.Steps[1].State = "done"
  Assert-Equal "save" (Send-StartupAct "save").Name "tout a jour : menu libre"
  Assert-Equal "save" (Get-StartupGate $null @{ Name = "save" } $script:St).Name "sans bloc de lancement : menu libre"

  New-StartupCase @("drive", "claude")
  $null = Invoke-StartupTicks
  $script:DriveJob.Loader = $null
  $script:DriveJob.Failed = $true
  $script:FakeOnline = $true
  $null = Invoke-StartupTicks
  Assert-True ($null -eq $script:Su.Exit -and $script:Su.Steps[0].State -eq "done") "echec avec internet : on continue"
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
  Assert-Equal ("failed " + (Get-ClmText "menu.startup.error")) ($script:Su.Steps[0].Kind + " " + $script:Su.Steps[0].Text) "Drive : erreur"

  New-StartupCase @("drive")
  $null = Invoke-StartupTicks
  $script:DriveJob.Loader = $null
  $script:DriveJob.Busy = $true
  $null = Invoke-StartupTicks
  Assert-Equal ("run " + (Get-ClmText "menu.startup.waiting_sync") + " 2") ($script:Su.Steps[0].State + " " + $script:Su.Steps[0].Text + " " + $script:DriveStarts) "Drive : synchro deja en cours, attente puis nouvel essai"
  Assert-Equal "none" (Send-StartupAct "launch").Name "Drive : compte refuse pendant l'attente"
  $script:DriveJob.Loader = $null
  $script:T += 60000
  $null = Invoke-StartupTicks
  Assert-Equal ("ok " + (Get-ClmText "menu.startup.left_to_other_clm")) ($script:Su.Steps[0].Kind + " " + $script:Su.Steps[0].Text) "Drive : attente trop longue, menu libre"

  Assert-Equal ("  " + (Get-ClmText "menu.startup.clm_update_failed" @("x"))) (Add-ClmFailure @("", $script:Ink.Dim) "x")[0] "erreur de clm sans autre message"
  Assert-Equal "  ok" (Add-ClmFailure @("  ok", $script:Ink.Dim) "")[0] "pas d'erreur de clm : message garde"
} finally { Restore-StartupFakes }
