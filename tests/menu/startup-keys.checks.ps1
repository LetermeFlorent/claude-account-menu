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
  $null = Invoke-StartupTicks 2
  Assert-Equal "quit 1 0" ($script:Su.Exit.Name + " " + $script:ClaudeStarts + " " + $script:DriveStarts) "Echap pendant Claude Code : mise a jour finie, synchro pas lancee"

  New-StartupCase @("claude", "drive")
  $script:St.Sel = 1
  $null = Invoke-StartupTicks 2
  $a = Send-StartupAct "launch"
  Assert-Equal "select 1" ($a.Name + " " + $a.Index) "Entree pendant la mise a jour : compte garde en surbrillance"
  Assert-Equal "  b : lancement a la fin de la mise a jour" $script:St.Msg[0] "Entree pendant la mise a jour : lancement annonce"
  $null = Invoke-StartupTicks
  Assert-Null $script:Su.Exit "Entree pendant la mise a jour : attend la fin de Claude Code"
  $null = Invoke-StartupTicks
  Assert-Equal "pick 1" ($script:Su.Exit.Name + " " + $script:Su.Exit.Index) "Entree pendant la mise a jour : compte lance a la fin"
  Assert-Equal 1 $script:DriveStarts "Entree pendant la mise a jour : synchro lancee avec le compte"

  New-StartupCase @("claude")
  $a = Send-StartupAct "pick" 2
  Assert-Equal "select 2 2" ($a.Name + " " + $a.Index + " " + $script:Su.Launch) "chiffre pendant la mise a jour : ce compte lance a la fin"
  $null = Send-StartupAct "quit"
  Assert-True ($script:Su.Quit -and $script:Su.Launch -lt 0) "Echap apres Entree : lancement annule"
  $null = Send-StartupAct "launch"
  Assert-True (-not $script:Su.Quit -and $script:Su.Launch -eq 0) "Entree apres Echap : arret annule"

  New-StartupCase @("claude", "drive")
  Assert-Equal "none" (Send-StartupAct "save").Name "commande pendant la mise a jour : refusee"
  Assert-Equal "  disponible a la fin de la mise a jour" $script:St.Msg[0] "commande pendant la mise a jour : raison affichee"
  Assert-Equal "up refresh" ((Send-StartupAct "up").Name + " " + (Send-StartupAct "refresh").Name) "deplacement et relecture pendant la mise a jour"
  $script:Su.Index = 1
  Assert-Equal "save launch quit" ((Send-StartupAct "save").Name + " " + (Send-StartupAct "launch").Name + " " + (Send-StartupAct "quit").Name) "pendant la synchro Drive : menu libre"
  Assert-Equal "save" (Get-StartupGate $null @{ Name = "save" } $script:St).Name "sans bloc de lancement : menu libre"

  foreach ($case in @(@("Failed", "failed erreur"), @("Busy", "ok en attente, un autre PC synchronise"))) {
    New-StartupCase @("drive")
    $null = Invoke-StartupTicks
    $script:DriveJob.Loader = $null
    $script:DriveJob[$case[0]] = $true
    $null = Invoke-StartupTicks
    Assert-Equal $case[1] ($script:Su.Steps[0].Kind + " " + $script:Su.Steps[0].Text) ("Drive : " + $case[0])
  }

  Assert-Equal "  mise a jour de clm impossible : x" (Add-ClmFailure @("", $script:Ink.Dim) "x")[0] "erreur de clm sans autre message"
  Assert-Equal "  ok" (Add-ClmFailure @("  ok", $script:Ink.Dim) "")[0] "pas d'erreur de clm : message garde"
} finally { Restore-StartupFakes }
