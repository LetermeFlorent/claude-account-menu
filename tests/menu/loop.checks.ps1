. (Join-Path $bin "claude-menu-loop.ps1")

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
$driveMocked = @("Invoke-DriveLogin", "Test-DriveConnected", "Test-DriveAuto", "Get-DriveLastSync", "Start-DriveJob")
$driveKept = @{}
foreach ($n in $driveMocked) { $f = Get-Item ("function:" + $n) -ErrorAction SilentlyContinue; if ($f) { $driveKept[$n] = $f.ScriptBlock } }
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
  param([object[]]$Keys)
  $script:UiKeys.Clear()
  $script:ClmCheck = $null
  $script:MenuRestart = $false
  foreach ($k in $Keys) {
    $c = [char]0
    if ($k -is [string]) { $c = [char]$k; $k = [ConsoleKey]::D2 }
    $script:UiKeys.Enqueue((New-Object System.ConsoleKeyInfo $c, $k, $false, $false, $false))
  }
  return Invoke-AccountMenu $false
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
} finally {
  foreach ($n in $mocked) { Set-Item -Path ("function:" + $n) -Value $kept[$n] }
  foreach ($n in $driveMocked) { if ($driveKept[$n]) { Set-Item -Path ("function:" + $n) -Value $driveKept[$n] } else { Remove-Item -Path ("function:" + $n) } }
  $script:DriveJob = $null
  $script:UiKeys.Clear()
  $script:ClmCheck = $null
  $script:MenuRestart = $false
}
