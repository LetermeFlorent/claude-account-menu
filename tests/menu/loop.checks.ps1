. (Join-Path $bin "claude-menu-loop.ps1")
. (Join-Path $bin "claude-menu-startup.ps1")

$mocked = @("Enter-UiScreen", "Exit-UiScreen", "Hide-Screen", "Show-Menu", "Start-MenuLoader", "Get-Accounts", "Update-UiTick", "New-ClmCheck")
$kept = @{}
foreach ($n in $mocked) { $kept[$n] = (Get-Item ("function:" + $n)).ScriptBlock }
function Enter-UiScreen { $script:UiOn = $true }
function Exit-UiScreen { $script:UiOn = $false }
function Hide-Screen {}
function Show-Menu { param($State, [double]$Now) $State.Dirty = $false }
function Start-MenuLoader { param($State) }
function Get-Accounts { return @(foreach ($l in @("a", "b", "c")) { [PSCustomObject]@{ Label = $l; Dir = (".claude-" + $l) } }) }
function Update-UiTick { param([double]$Now, [bool]$Busy) return $false }
$script:FakeLatest = $null
function New-ClmCheck { return @{ Loader = $null; NextAt = $null; Installed = $null; Latest = $script:FakeLatest } }
$softMocked = @("Invoke-DriveLogin", "Test-DriveConnected", "Test-DriveAuto", "Get-DriveLastSync", "Start-DriveJob", "Start-ClaudeUpdate", "Step-ClaudeUpdate")
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
function Invoke-DriveLogin {
  $script:LoginCalls++
  $script:UiAtLogin = $script:UiOn
  if ($script:LoginFails) { throw "refus" }
  return "Drive connecte sur pc"
}
function Test-DriveConnected { return -not $script:LoginFails }
function Test-DriveAuto { return $false }
function Get-DriveLastSync { return [long]0 }
$script:SyncStarts = 0
function Start-DriveJob { param($Job) $script:SyncStarts++ }

function Invoke-WithKeys {
  param([object[]]$Keys, [bool]$Update = $false)
  $script:UiKeys.Clear()
  $script:ClmCheck = $null
  $script:MenuRestart = $false
  foreach ($k in $Keys) {
    $c = [char]0
    if ($k -is [string]) { $c = [char]$k; $k = [ConsoleKey]::D2 }
    $script:UiKeys.Enqueue((New-Object System.ConsoleKeyInfo $c, $k, $false, $false, $false))
  }
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
  Assert-Null (Invoke-WithKeys @("y", [ConsoleKey]::Escape)) "y sans Drive : menu garde"
  Assert-Equal "  connexion Drive impossible : refus" $script:MenuState.Msg[0] "y sans Drive : echec affiche"
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
  Assert-Equal " 1" ("" + (Invoke-WithKeys @([ConsoleKey]::DownArrow, [ConsoleKey]::Enter, [ConsoleKey]::Escape) $true).Label + " " + $script:ClaudeStarts) "pendant la mise a jour : Entree refusee, aucun compte lance"
  Assert-Null (Invoke-WithKeys @([ConsoleKey]::DownArrow, [ConsoleKey]::Escape) $true) "Echap pendant la mise a jour : menu quitte a la fin"
  Assert-Equal "2   a, b, c : Claude Code a jour (2.1.292)" ("" + $script:ClaudeStarts + " " + $script:MenuState.Msg[0]) "Echap pendant la mise a jour : mise a jour menee au bout"
  Assert-Null $script:Startup "menu ferme : bloc de lancement oublie"
  Assert-Null (Invoke-WithKeys @([ConsoleKey]::Escape) $true) "Echap avant la mise a jour : menu quitte"
  Assert-Equal 2 $script:ClaudeStarts "Echap avant la mise a jour : rien lance"
} finally {
  foreach ($n in $mocked) { Set-Item -Path ("function:" + $n) -Value $kept[$n] }
  foreach ($n in $softMocked) { if ($softKept[$n]) { Set-Item -Path ("function:" + $n) -Value $softKept[$n] } else { Remove-Item -Path ("function:" + $n) } }
  $script:DriveJob = $null
  $script:Startup = $null
  $script:UiKeys.Clear()
  $script:ClmCheck = $null
  $script:MenuRestart = $false
}
