. (Join-Path $bin "claude-menu-loop.ps1")
. (Join-Path $bin "claude-menu-startup.ps1")
if (-not (Test-Path Function:\Invoke-DriveSetup)) { . (Join-Path $bin "claude-sync-passphrase.ps1") }
$mocked = @("Enter-UiScreen", "Exit-UiScreen", "Hide-Screen", "Show-Menu", "Start-MenuLoader", "Get-Accounts", "Update-UiTick", "New-ClmCheck", "Read-UiInput")
$kept = @{}
foreach ($n in $mocked) { $kept[$n] = (Get-Item ("function:" + $n)).ScriptBlock }
$script:InputLog = New-Object 'System.Collections.Generic.List[string]'
$script:StaleInput = New-Object 'System.Collections.Generic.Queue[object]'
$script:FreshInput = New-Object 'System.Collections.Generic.Queue[object]'
$script:OneAccount = $false
function Enter-UiScreen { $script:UiOn = $true }
function Exit-UiScreen { $script:UiOn = $false }
function Hide-Screen {}
function Show-Menu { param($State, [double]$Now) $script:InputLog.Add("draw"); $State.Dirty = $false }
function Start-MenuLoader { param($State) }
function Get-Accounts {
  $labels = @("a", "b", "c")
  if ($script:OneAccount) { $labels = @("a") }
  return @(foreach ($l in $labels) { [PSCustomObject]@{ Label = $l; Dir = (".claude-" + $l) } })
}
function Read-UiInput {
  $script:InputLog.Add("read")
  if ($script:StaleInput.Count -gt 0) { return $script:StaleInput.Dequeue() }
  if ($script:FreshAfterStartup -and (Test-StepsLeft $script:Startup @())) { return $null }
  if ($script:FreshInput.Count -gt 0) { return $script:FreshInput.Dequeue() }
  return $null
}
function Update-UiTick { param([double]$Now, [bool]$Busy) return $false }
$script:FakeLatest = $null
function New-ClmCheck { return @{ Loader = $null; NextAt = $null; Installed = $null; Latest = $script:FakeLatest } }
$softMocked = @("Invoke-DriveLogin", "Test-DriveConnected", "Test-DriveAuto", "Get-DriveLastSync", "Start-DriveJob", "Start-ClaudeUpdate", "Step-ClaudeUpdate", "Set-SyncPassphrase", "Test-SyncKeyStored", "Clear-ConsoleInput")
$softKept = @{}
foreach ($n in $softMocked) { $f = Get-Item ("function:" + $n) -ErrorAction SilentlyContinue; if ($f) { $softKept[$n] = $f.ScriptBlock } }
$script:ClaudeStarts = 0
function Start-ClaudeUpdate { param([string]$Exe, $Acc) $script:ClaudeStarts++; return @{ Left = 2; State = (New-UpdateState); Watch = $null; Outcome = $null } }
function Step-ClaudeUpdate {
  param($Run)
  $Run.Left = $Run.Left - 1
  if ($Run.Left -gt 0) { return $false }
  $Run.Outcome = New-Outcome "ok" "Claude Code a jour (2.1.292)"
  return $true
}
function Clear-ConsoleInput { $script:InputLog.Add("flush"); $script:StaleInput.Clear() }
function Invoke-DriveLogin {
  $script:LoginCalls++
  $script:UiAtLogin = $script:UiOn
  if ($script:LoginLeavesEnter) { $script:StaleInput.Enqueue((New-TestKey ([ConsoleKey]::Enter))) }
  if ($script:LoginFails) { throw "refus" }
  $script:DriveOn = $true
  return "Drive connecte sur pc"
}
$script:DriveOn = $true
$script:KeyStored = $true
$script:PassCalls = 0
function Test-DriveConnected { return $script:DriveOn }
function Test-SyncKeyStored { return $script:KeyStored }
function Set-SyncPassphrase { $script:PassCalls++; $script:KeyStored = $true; return "phrase de synchro enregistree sur ce PC" }
function Test-DriveAuto { return $false }
function Get-DriveLastSync { return [long]0 }
$script:SyncStarts = 0
function Start-DriveJob { param($Job) $script:SyncStarts++ }

function New-TestKey {
  param($Key)
  $c = [char]0
  if ($Key -is [string]) { $c = [char]$Key; $Key = [ConsoleKey]::D2 }
  return New-Object System.ConsoleKeyInfo $c, $Key, $false, $false, $false
}

function Invoke-WithKeys {
  param([object[]]$Keys, [bool]$Update = $false, [object[]]$Stale = @())
  $script:ClmCheck = $null
  $script:MenuRestart = $false
  $script:InputLog.Clear()
  $script:InputGate.Held.Clear()
  $script:StaleInput.Clear()
  $script:FreshInput.Clear()
  foreach ($k in $Stale) { $script:StaleInput.Enqueue((New-TestKey $k)) }
  foreach ($k in $Keys) { $script:FreshInput.Enqueue((New-TestKey $k)) }
  return Invoke-AccountMenu $Update
}

try {
  Assert-Equal "b" (Invoke-WithKeys @([ConsoleKey]::DownArrow, [ConsoleKey]::Enter)).Label "fleche bas puis Entree"
  Assert-Equal "c" (Invoke-WithKeys @([ConsoleKey]::UpArrow, [ConsoleKey]::Enter)).Label "fleche haut fait le tour"
  Assert-Equal "b" (Invoke-WithKeys @("2")).Label "chiffre lance le compte"
  Assert-Null (Invoke-WithKeys @([ConsoleKey]::Escape)) "Echap quitte"
  Assert-Null (Invoke-WithKeys @([string][char]3)) "Ctrl+C quitte"
  Assert-True (-not $script:UiOn) "ecran rendu en sortie"
  Assert-Null (Invoke-WithKeys @("u", [ConsoleKey]::Escape)) "u sans nouvelle version, menu garde"
  Assert-True (-not $script:MenuRestart) "u sans nouvelle version, pas de redemarrage"
  $script:FakeLatest = [PSCustomObject]@{ Sha = ("b" * 40); Time = 2; Number = 0 }
  Assert-Null (Invoke-WithKeys @("u")) "u avec nouvelle version, menu ferme"
  Assert-True $script:MenuRestart "u avec nouvelle version, redemarrage demande"
  $script:FakeLatest = $null
  $script:DriveJob = New-DriveJob $false 0
  $script:LoginCalls = 0
  $script:LoginFails = $true
  $script:DriveOn = $false
  Assert-Null (Invoke-WithKeys @("y", [ConsoleKey]::Escape)) "y sans Drive : menu garde"
  Assert-Equal ("  " + (Get-ClmText "menu.loop.fail.drive.login" @("refus"))) $script:MenuState.Msg[0] "y sans Drive : echec affiche"
  Assert-True (-not $script:DriveJob.Connected) "y sans Drive : echec, toujours deconnecte"
  $script:LoginFails = $false
  $null = Invoke-WithKeys @("y", [ConsoleKey]::Escape)
  Assert-Equal 2 $script:LoginCalls "y sans Drive : connexion lancee"
  Assert-True (-not $script:UiAtLogin) "y sans Drive : connexion hors de l'ecran du menu"
  Assert-Equal "  Drive connecte sur pc" $script:MenuState.Msg[0] "y sans Drive : connexion annoncee"
  Assert-True $script:DriveJob.Connected "y sans Drive : tache reconnectee"
  Assert-Equal 1 $script:SyncStarts "y sans Drive : synchro lancee apres connexion"
  Assert-True $script:DriveJob.Notify "y sans Drive : resultat de la synchro annonce"
  $null = Invoke-WithKeys @("y", [ConsoleKey]::Escape)
  Assert-Equal 2 $script:LoginCalls "y avec Drive : pas de nouvelle connexion"
  Assert-Equal 0 $script:PassCalls "y avec Drive et phrase : phrase jamais redemandee"
  $script:KeyStored = $false
  $null = Invoke-WithKeys @("y", [ConsoleKey]::Escape)
  Assert-Equal "2 1" ("" + $script:LoginCalls + " " + $script:PassCalls) "y avec Drive sans phrase : phrase demandee, pas de nouvelle connexion"
  Assert-Equal "  phrase de synchro enregistree sur ce PC" $script:MenuState.Msg[0] "y avec Drive sans phrase : phrase annoncee"
  Assert-Equal " 1" ("" + (Invoke-WithKeys @([ConsoleKey]::DownArrow, [ConsoleKey]::Enter, [ConsoleKey]::Escape) $true).Label + " " + $script:ClaudeStarts) "pendant la mise a jour : Entree puis Echap, aucun compte lance"
  Assert-Null (Invoke-WithKeys @([ConsoleKey]::DownArrow, [ConsoleKey]::Escape) $true) "Echap pendant la mise a jour : menu quitte a la fin"
  Assert-Equal "2   a, b, c : Claude Code a jour (2.1.292)" ("" + $script:ClaudeStarts + " " + $script:MenuState.Msg[0]) "Echap pendant la mise a jour : mise a jour menee au bout"
  Assert-Null $script:Startup "menu ferme : bloc de lancement oublie"
  Assert-Null (Invoke-WithKeys @([ConsoleKey]::Escape) $true) "Echap avant la mise a jour : menu quitte"
  Assert-Equal 2 $script:ClaudeStarts "Echap avant la mise a jour : rien lance"
  Assert-Equal "b 3" ("" + (Invoke-WithKeys @([ConsoleKey]::DownArrow, [ConsoleKey]::Enter) $true).Label + " " + $script:ClaudeStarts) "Entree pendant la mise a jour : compte lance a la fin"
  $script:OneAccount = $true
  Assert-Null (Invoke-WithKeys @([ConsoleKey]::Escape) $false @([ConsoleKey]::Enter)) "un seul compte : Entree restee dans la console au lancement, aucun compte ouvert"
  Assert-Equal "draw flush" (@($script:InputLog | Select-Object -First 2) -join " ") "un seul compte : menu affiche puis console videe avant toute lecture"
  $script:UiKeys.Enqueue((New-TestKey ([ConsoleKey]::Enter)))
  Assert-Null (Invoke-WithKeys @([ConsoleKey]::Escape)) "un seul compte : Entree lue avant l'affichage, aucun compte ouvert"
  $script:FreshAfterStartup = $true
  Assert-Null (Invoke-WithKeys @([ConsoleKey]::Escape) $true @("1")) "un seul compte : 1 reste dans la console au lancement, rien ouvert a la fin des mises a jour"
  $script:FreshAfterStartup = $false
  Assert-Equal "a" (Invoke-WithKeys @([ConsoleKey]::Enter) $false @([ConsoleKey]::Enter)).Label "un seul compte : Entree apres l'affichage, compte ouvert"
  $script:OneAccount = $false
  $script:DriveJob = New-DriveJob $false 0
  $script:DriveOn = $false
  $script:LoginLeavesEnter = $true
  Assert-Null (Invoke-WithKeys @("y", [ConsoleKey]::Escape)) "Entree laissee par la connexion Drive : retour au menu sans ouvrir de compte"
} finally {
  $script:OneAccount = $false
  $script:LoginLeavesEnter = $false
  $script:FreshAfterStartup = $false
  foreach ($n in $mocked) { Set-Item -Path ("function:" + $n) -Value $kept[$n] }
  foreach ($n in $softMocked) { if ($softKept[$n]) { Set-Item -Path ("function:" + $n) -Value $softKept[$n] } else { Remove-Item -Path ("function:" + $n) } }
  $script:DriveJob = $null
  $script:Startup = $null
  $script:UiKeys.Clear()
  $script:ClmCheck = $null
  $script:MenuRestart = $false
}
