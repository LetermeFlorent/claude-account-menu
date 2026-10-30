. (Join-Path $PSScriptRoot "startup-fakes.ps1")

try {
  Assert-Equal "clm|claude|drive" ((Get-StartupNames $true $true) -join "|") "lancement : clm, Claude Code puis Drive"
  Assert-Equal "claude|drive" ((Get-StartupNames $true $false) -join "|") "apres redemarrage : pas de nouvelle recherche de clm"
  $script:FakeInstalled = $false
  Assert-Equal "claude|drive" ((Get-StartupNames $true $true) -join "|") "clm hors de son dossier : pas de mise a jour de clm"
  $script:FakeInstalled = $true; $script:FakeAuto = $false
  Assert-Equal "clm|claude" ((Get-StartupNames $true $true) -join "|") "synchro auto coupee : pas de barre Drive"
  Assert-Equal "" ((Get-StartupNames $false $false) -join "|") "sans mise a jour ni synchro : aucune etape"
  $script:DriveHolds = 0
  Open-MenuSession $false $false
  Assert-True ($script:Startup.Hidden -and $script:DriveHolds -eq 0) "sans mise a jour ni synchro : pas de bloc, Drive pas charge"

  $script:FakeAuto = $true; $script:DriveJob = $null; $script:DriveStarts = 0; $script:MenuLoads = 0
  Open-MenuSession $true $true
  $script:Su = $script:Startup
  Assert-Equal "clm|Claude Code|Drive" (Get-StepList "Label") "ouverture : une barre par etape"
  Assert-Equal ("|" + (Get-ClmText "menu.startup.after" @("clm")) + "|" + (Get-ClmText "menu.startup.after" @("clm"))) (Get-StepList "Text") "ouverture : Claude Code et Drive attendent clm"
  Assert-Equal "3 1" ("" + $script:MenuState.Entries.Count + " " + $script:MenuLoads) "ouverture : comptes et quotas tout de suite"
  Assert-True ($script:DriveJob.Connected -and $script:DriveStarts -eq 0) "ouverture : Drive pret, synchro pas encore lancee"
  Assert-Equal 1 $script:DriveHolds "ouverture : synchro chargee en avance pendant la verification de clm"

  New-StartupCase @("clm", "claude", "drive")
  Assert-True (Invoke-StartupTicks) "clm : barre redessinee au demarrage"
  Assert-Equal "Find-ClmUpdate" ($script:Loads -join "|") "clm : recherche lancee a part"
  Assert-True $script:ClmChecked "clm : pas de nouvelle recherche en mode texte"
  Assert-Equal ((Get-ClmText "update.startup.searching") + "|" + (Get-ClmText "menu.startup.after" @("clm")) + "|" + (Get-ClmText "menu.startup.after" @("clm"))) (Get-StepList "Text") "clm : recherche affichee"
  Assert-True (-not (Invoke-StartupTicks)) "clm : rien a redessiner pendant la recherche"
  Assert-True (Test-StartupBlocking $script:Su) "clm : comptes caches pendant la verification"
  $script:Work.Ctl.Done = $true
  $null = Invoke-StartupTicks
  Assert-Equal "done|run|run" (Get-StepList "State") "clm a jour : Claude Code et Drive lances ensemble"
  Assert-True (-not (Test-StartupBlocking $script:Su)) "clm a jour : comptes affiches tout de suite"
  Assert-Equal ((Get-ClmText "update.startup.upToDate") + " 100") ($script:Su.Steps[0].Text + " " + $script:Su.Steps[0].Bar.To) "clm a jour : barre pleine"
  Assert-Equal 1 $script:DriveStarts "Drive : lance des que clm est a jour"
  $null = Invoke-StartupTicks
  Assert-Equal 1 $script:ClaudeStarts "Claude Code : lance apres clm"
  Assert-True $script:MenuUpdated "Claude Code : pas relance en mode texte"
  $run = $script:Su.Steps[1].Run
  $run.State.Mode = "native"; $run.State.Target = "2.1.300"
  $run.Watch = @{ Seen = $true; Settled = $false; Bytes = 45MB; Size = 100MB }
  $null = Invoke-StartupTicks
  Assert-Equal ("45 " + (Get-ClmText "update.claude.downloading" @("2.1.300")) + "  " + (Get-ClmText "update.claude.sizeBoth" @(45, 100))) ("" + $script:Su.Steps[1].Pct + " " + $script:Su.Steps[1].Text) "Claude Code : telechargement suivi"
  Assert-Equal (Get-ClmText "menu.startup.preparing") $script:Su.Steps[2].Text "Drive : en cours pendant Claude Code"
  $null = Invoke-StartupTicks
  Assert-Equal ((Get-ClmText "update.claude.upToDateVersion" @("2.1.292")) -replace "^Claude Code ", "") $script:Su.Steps[1].Text "Claude Code a jour : annonce"
  Assert-Equal ("  a, b, c : " + (Get-ClmText "update.claude.upToDateVersion" @("2.1.292"))) $script:St.Msg[0] "Claude Code a jour : resultat sous les comptes"
  $script:DriveJob.Ctl.Progress = "3/10"
  Assert-True (Invoke-StartupTicks) "Drive : avancement redessine"
  Assert-Equal ("30 " + (Get-ClmText "menu.startup.files" @("3/10"))) ("" + $script:Su.Steps[2].Pct + " " + $script:Su.Steps[2].Text) "Drive : fichiers faits sur le total"
  $script:DriveJob.Loader = $null
  $null = Invoke-StartupTicks 2
  Assert-Equal (Get-ClmText "menu.startup.upToDate") $script:Su.Steps[2].Text "Drive : synchro finie"
  Assert-Equal "True|False|False" (Get-StepList "Gone") "clm a jour : ligne effacee, Claude Code et Drive gardes un instant"
  Assert-Equal 3 (Get-StartupRowCount $script:Su) "clm a jour : une rangee de moins"
  Assert-True (-not $script:Su.Hidden) "fin : barres gardees un instant"
  $null = Invoke-StartupTicks 10
  Assert-True $script:Su.Hidden "fin : chaque ligne a jour partie seule"
  Assert-Null $script:Su.Exit "fin : menu garde ouvert"

  New-StartupCase @("clm", "claude", "drive")
  $script:FakeLatest = $script:FakeV62
  $null = Invoke-StartupTicks; $script:Work.Ctl.Done = $true
  $null = Invoke-StartupTicks
  Assert-Equal "Find-ClmUpdate|Install-ClmVersion 62" (($script:Loads -join "|") + " " + $script:InstallItem.Number) "nouvelle version de clm : celle trouvee, installee"
  Assert-True ($script:Su.Steps[0].Text -like ((Get-ClmText "update.startup.installing" @((Get-ClmText "update.self.versionAt" @("v62", "")))) + "*")) "nouvelle version de clm : affichee"
  $script:Work.Ctl.Done = $true
  $null = Invoke-StartupTicks 3
  Assert-Equal (Get-ClmText "update.startup.withRestart" @(Get-ClmText "update.startup.installed" @("v62"))) $script:Su.Steps[0].Text "nouvelle version de clm : redemarrage annonce"
  Assert-True $script:ClmUpdated "nouvelle version de clm : redemarrage demande"
  Assert-Equal "restart" (Send-StartupAct "up").Name "nouvelle version de clm : menu ferme pour redemarrer"
  Assert-Equal 0 ($script:ClaudeStarts + $script:DriveStarts) "nouvelle version de clm : ni Claude Code ni Drive avant le redemarrage"
  $script:FakeLatest = $null

  New-StartupCase @("clm", "claude")
  $script:FakeLatest = $script:FakeV62
  $script:FakeInstallError = "disque plein"
  $null = Invoke-StartupTicks; $script:Work.Ctl.Done = $true
  $null = Invoke-StartupTicks; $script:Work.Ctl.Done = $true
  $null = Invoke-StartupTicks
  Assert-Equal ("failed " + (Get-ClmText "update.startup.installFailed" @("disque plein"))) ($script:Su.Steps[0].Kind + " " + $script:Su.Steps[0].Text) "installation de clm ratee : barre en erreur"
  Assert-Equal ("  " + (Get-ClmText "menu.startup.clmUpdateFailed" @("disque plein"))) $script:St.Msg[0] "installation de clm ratee : annoncee tout de suite"
  $null = Invoke-StartupTicks 4
  Assert-Equal ("  " + (Get-ClmText "menu.startup.clmUpdateFailed" @("disque plein")) + "   a, b, c : " + (Get-ClmText "update.claude.upToDateVersion" @("2.1.292"))) $script:St.Msg[0] "installation de clm ratee : erreur puis resultat de Claude Code"
  Assert-Equal $script:Ink.Alert $script:St.Msg[1] "installation de clm ratee : couleur d'alerte"
  Assert-True (-not $script:ClmUpdated -and $null -eq $script:Su.Exit) "installation de clm ratee : pas de redemarrage"
  $script:FakeInstallError = $null

  New-StartupCase @("clm", "claude")
  $script:FakeFindError = "hors ligne"
  $null = Invoke-StartupTicks; $script:Work.Ctl.Done = $true
  $null = Invoke-StartupTicks 3
  Assert-Equal ("failed " + (Get-ClmText "update.startup.searchFailed")) ($script:Su.Steps[0].Kind + " " + $script:Su.Steps[0].Text) "recherche de clm ratee : barre en erreur"
  Assert-Equal 1 $script:ClaudeStarts "recherche de clm ratee : Claude Code continue"
  $null = Invoke-StartupTicks 2
  Assert-Equal "done|done False|False" ((Get-StepList "State") + " " + (Get-StepList "Gone")) "fin avec un echec : lignes gardees un instant"
  $null = Invoke-StartupTicks 4
  Assert-Equal "False|True" (Get-StepList "Gone") "fin avec un echec : ligne a jour partie, ligne en erreur restee"
  $null = Invoke-StartupTicks 20
  Assert-True (-not $script:Su.Hidden -and (Get-StepList "Gone") -eq "False|True") "fin avec un echec : ligne en erreur gardee a l'ecran"
  $script:FakeFindError = $null
  $script:FakeLatest = $null

  New-StartupCase @("claude")
  $script:FakeClaudeFail = "echec de la mise a jour : EBUSY"
  $null = Invoke-StartupTicks 5
  Assert-Equal ("failed " + (Get-ClmText "update.startup.claudeFailed")) ($script:Su.Steps[0].Kind + " " + $script:Su.Steps[0].Text) "Claude Code en echec : la ligne dit echec"
  Assert-Equal "  a, b, c : echec de la mise a jour : EBUSY" $script:St.Msg[0] "Claude Code en echec : la raison sous les comptes"
  $null = Invoke-StartupTicks 20
  Assert-True (-not $script:Su.Hidden -and -not $script:Su.Steps[0].Gone) "Claude Code en echec : la ligne reste"
  $script:FakeClaudeFail = $null

  $w = New-FakeWork $null
  Assert-Null (Receive-LoaderValue $w) "tache a part : rien tant qu'elle tourne"
  $w.Ctl.Done = $true; $w.Ctl.Error = "module absent"
  Assert-Equal "module absent" (Receive-LoaderValue $w).Error "tache a part : erreur de chargement remontee"
} finally { Restore-StartupFakes }
