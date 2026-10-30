. (Join-Path $PSScriptRoot "update-fakes.ps1")

$busyLine = "Another Claude process (PID 4242) is currently running. Please try again in a moment."
$o = Get-OutcomeFor @("Current version: 2.1.304", "Checking for updates to latest version...", $busyLine)
Assert-Equal "failed" $o.Kind "verrou pris, code 0 : echec quand meme"
Assert-Equal (Get-ClmText "update.claude.busyHolder" @("4242")) $o.Text "verrou pris : session qui bloque"

$o = Get-OutcomeFor @("Current version: 2.1.304", "Error: Failed to install native update", "EBUSY: resource busy or locked", 'Try running "claude doctor" for diagnostics') 1
Assert-Equal (Get-ClmText "update.claude.failed" @("EBUSY: resource busy or locked")) $o.Text "erreur : la vraie raison, ligne suivante"
$o = Get-OutcomeFor @("Error: Failed to install native update", 'Try running "claude doctor" for diagnostics') 1
Assert-Equal (Get-ClmText "update.claude.failed" @("Error: Failed to install native update")) $o.Text "erreur sans raison : la ligne d'erreur"

$st = New-UpdateState
Add-UpdateLine $st "@latest is at 2.1.300 (older than 2.1.308)..."
Assert-Equal "native 2.1.300" ($st.Mode + " " + $st.Target) "canal plus ancien : retour en arriere natif"
$o = Get-OutcomeFor @("Current version: 2.1.308", 'Update target 2.1.300 (from @latest or a server-side override) predates release-signature enforcement; staying on 2.1.308. Run `claude install 2.1.300` to install it anyway.')
Assert-Equal ("ok " + (Get-ClmText "update.claude.upToDateVersion" @("2.1.308"))) ($o.Kind + " " + $o.Text) "cible trop ancienne : reste a jour"
$o = Get-OutcomeFor @("Current version: 2.1.308", "The stable channel is at 2.1.300, which is older. Staying on 2.1.308.")
Assert-Equal (Get-ClmText "update.claude.upToDateVersion" @("2.1.308")) $o.Text "canal plus ancien : reste a jour"

$fail = New-Outcome "failed" "x"
$r = @{ Exe = "x"; CanRetry = $true; BusyFrom = -1.0; Tries = 1; State = @{ Busy = $true } }
Assert-Equal 5 (Get-UpdateRetryPause $r $fail 10) "verrou pris : nouvel essai dans 5 s"
Assert-Equal 5 (Get-UpdateRetryPause $r $fail 69.9) "verrou pris depuis 59,9 s : on attend encore"
Assert-Equal -1 (Get-UpdateRetryPause $r $fail 70) "verrou pris depuis une minute : abandon"
$r.State = @{ Busy = $false }
Assert-Equal "2 2 -1" ("" + (Get-UpdateRetryPause $r $fail 1) + " " + (Get-UpdateRetryPause $r $fail 1) + " " + (Get-UpdateRetryPause $r $fail 1)) "autre echec : trois essais au plus"
$r.Tries = 1
Assert-Equal -1 (Get-UpdateRetryPause $r (New-Outcome "ok" "x") 1) "pas d'echec, pas de nouvel essai"
$r.CanRetry = $false
Assert-Equal -1 (Get-UpdateRetryPause $r $fail 1) "arret demande : pas de nouvel essai"

$keptStart = ${function:Start-UpdateProcess}
$keptPause = $script:UpdateRetryPause
$keptBusy = $script:UpdateBusyPause
$exe = New-SandboxFile "retry/claude.exe" ""
$acc = [PSCustomObject]@{ Label = "a"; Dir = ".claude" }
$errText = "Error: Failed to install native update`nEBUSY: resource busy or locked"
function Set-FakeProcs {
  param($Procs)
  $script:FakeProcs = @($Procs)
  $script:FakeStarts = 0
}
function Invoke-UpdateSteps {
  param($Run)
  for ($i = 0; $i -lt 20; $i++) { if (Step-ClaudeUpdate $Run) { return } }
}
try {
  $script:UpdateRetryPause = 0
  $script:UpdateBusyPause = 0
  ${function:Start-UpdateProcess} = { param([string]$Exe) $p = $script:FakeProcs[$script:FakeStarts]; $script:FakeStarts++; return $p }

  $busy = New-FakeUpdateProc $true ("Current version: 2.1.304`n" + $busyLine)
  Set-FakeProcs @($busy, (New-FakeUpdateProc $true "Updating to 2.1.308...`nSuccessfully updated from 2.1.304 to version 2.1.308"))
  $run = Start-ClaudeUpdate $exe $acc
  Assert-Equal $false (Step-ClaudeUpdate $run) "verrou pris : on ne s'arrete pas"
  Assert-Equal (Get-ClmText "update.claude.waitSessionPid" @("4242")) (Get-UpdateTick $run.State $run.Watch).Label "verrou pris : attente affichee"
  Assert-Equal $false (Step-ClaudeUpdate $run) "verrou pris : nouvel essai lance"
  Assert-Equal (Get-ClmText "update.claude.waitSessionPid" @("4242")) (Get-UpdateTick $run.State $run.Watch).Label "nouvel essai : attente gardee pendant la recherche"
  Invoke-UpdateSteps $run
  Assert-Equal ("2 " + (Get-ClmText "update.claude.updated" @("2.1.304", "2.1.308"))) ("" + $script:FakeStarts + " " + $run.Outcome.Text) "verrou libere : mise a jour faite"
  Assert-True $busy.Disposed "verrou pris : premier processus libere"

  Set-FakeProcs @(1..4 | ForEach-Object { New-FakeUpdateProc $true "Current version: 2.1.304" $errText 1 })
  $run = Start-ClaudeUpdate $exe $acc
  $null = Step-ClaudeUpdate $run
  Assert-Equal (Get-ClmText "update.claude.retry" @(2, 3)) (Get-UpdateTick $run.State $run.Watch).Label "erreur : deuxieme essai annonce"
  Invoke-UpdateSteps $run
  Assert-Equal ("3 " + (Get-ClmText "update.claude.failed" @("EBUSY: resource busy or locked"))) ("" + $script:FakeStarts + " " + $run.Outcome.Text) "erreur repetee : trois essais puis echec"

  Set-FakeProcs @((New-FakeUpdateProc $true $busyLine))
  $run = Start-ClaudeUpdate $exe $acc
  $null = Step-ClaudeUpdate $run
  $run.CanRetry = $false
  Assert-Equal $true (Step-ClaudeUpdate $run) "arret demande pendant l'attente : fin tout de suite"
  Assert-Equal ("1 " + (Get-ClmText "update.claude.busyHolder" @("4242"))) ("" + $script:FakeStarts + " " + $run.Outcome.Text) "arret demande : dernier resultat garde"

  Set-FakeProcs @((New-FakeUpdateProc $true "" $errText 1))
  $run = Start-ClaudeUpdate $exe $acc
  $null = Step-ClaudeUpdate $run
  Remove-Item -LiteralPath $exe
  Invoke-UpdateSteps $run
  Assert-Equal (Get-ClmText "update.claude.missing") $run.Outcome.Text "Claude Code disparu avant le nouvel essai"
} finally {
  ${function:Start-UpdateProcess} = $keptStart
  $script:UpdateRetryPause = $keptPause
  $script:UpdateBusyPause = $keptBusy
}
