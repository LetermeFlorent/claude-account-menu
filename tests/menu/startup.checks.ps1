. (Join-Path $bin "claude-menu-loop.ps1")
. (Join-Path $bin "claude-menu-startup.ps1")

$startupMocked = @("Enter-UiScreen", "Exit-UiScreen", "Hide-Screen", "Show-Menu", "Show-WorkPage", "Start-MenuLoader", "Get-Accounts", "Update-UiTick", "New-ClmCheck", "Start-UsageLoader", "Wait-Progress", "Test-ClmInstalledHere", "Invoke-UiWork", "Invoke-UiLoader", "Update-ClaudeForAccounts")
$startupKept = @{}
foreach ($n in $startupMocked) { $startupKept[$n] = (Get-Item ("function:" + $n)).ScriptBlock }

function New-FakeStartupLoader {
  param([bool]$Done, $Item, [string]$CtlError = $null)
  $q = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
  if ($null -ne $Item) { $q.Enqueue($Item) }
  return @{ Ps = $null; Ctl = @{ Done = $Done; Error = $CtlError }; Queue = $q }
}

function Invoke-Startup {
  param([bool]$Update, [bool]$SelfUpdate)
  $script:Screens = @()
  $script:Loads = @()
  $script:DriveJob = New-DriveJob $false 0
  $script:UiKeys.Clear()
  foreach ($k in @([ConsoleKey]::DownArrow, [ConsoleKey]::Escape)) { $script:UiKeys.Enqueue((New-Object System.ConsoleKeyInfo ([char]0), $k, $false, $false, $false)) }
  return Invoke-AccountMenu $Update $SelfUpdate
}

try {
  function Hide-Screen {}
  function Show-WorkPage {}
  function Start-UsageLoader { param($Accounts, [string]$Source, [string]$Reader) $script:LoaderCall = @($Accounts, $Source, $Reader); return $script:FakeLd }
  function Wait-Progress { param([int]$Ms) $script:Waits++; $script:FakeLd.Ctl.Done = $true }

  $script:UiKeys.Clear()
  Assert-Equal "fait" (Invoke-UiWork "Titre" "texte" { $script:UiKeys.Enqueue("k"); "fait" }) "ecran d'attente : resultat rendu"
  Assert-Equal 0 $script:UiKeys.Count "ecran d'attente : touches tapees pendant l'attente oubliees"
  Assert-Null $script:UiPulse "ecran d'attente : animation arretee a la fin"

  $script:Waits = 0
  $script:FakeLd = New-FakeStartupLoader $false @(0, "v1", $null)
  Assert-Equal "v1" (Invoke-UiLoader "recherche" @(0) "src.ps1" "Find-ClmUpdate") "tache d'attente : valeur rendue"
  Assert-Equal 1 $script:Waits "tache d'attente : ecran anime tant qu'elle tourne"
  Assert-Equal "Find-ClmUpdate" $script:LoaderCall[2] "tache d'attente : fonction lancee a part"
  Assert-Equal "recherche" $script:UiProgress.Label "tache d'attente : barre affichee"
  Assert-Equal -1 $script:UiProgress.Pct "tache d'attente : barre sans pourcentage"
  $script:UiProgress = $null
  foreach ($case in @(@((New-FakeStartupLoader $true @(0, $null, "panne reseau")), "panne reseau"), @((New-FakeStartupLoader $true $null "module absent"), "module absent"))) {
    $script:FakeLd = $case[0]
    $err = $null
    try { $null = Invoke-UiLoader "x" @(0) "s" "r" } catch { $err = $_.Exception.Message }
    Assert-Equal $case[1] $err ("tache d'attente : erreur relancee, " + $case[1])
  }

  function Enter-UiScreen { $script:UiOn = $true }
  function Exit-UiScreen { $script:UiOn = $false }
  function Show-Menu { param($State, [double]$Now) $State.Dirty = $false; if ($script:Screens[-1] -ne "menu") { $script:Screens += "menu" } }
  function Start-MenuLoader { param($State) }
  function Get-Accounts { return @(foreach ($l in @("a", "b", "c")) { [PSCustomObject]@{ Label = $l; Dir = (".claude-" + $l) } }) }
  function Update-UiTick { param([double]$Now, [bool]$Busy) return $false }
  function New-ClmCheck { return @{ Loader = $null; NextAt = $null; Installed = $null; Latest = $null } }
  function Test-ClmInstalledHere { return $script:FakeInstalled }
  function Invoke-UiWork { param([string]$Title, [string]$Text, [scriptblock]$Work) $script:Screens += $Title; $script:WorkPage = @{ Title = $Title; Text = $Text }; return (& $Work) }
  function Invoke-UiLoader {
    param([string]$Label, $Items, [string]$Source, [string]$Reader)
    $script:Loads += $Reader
    if ($Reader -eq "Find-ClmUpdate") { $script:UiQuit = $script:QuitOnFind; return $script:FakeLatest }
    $script:InstallItem = @($Items)[0]
    if ($script:FakeInstallError) { throw $script:FakeInstallError }
  }
  function Update-ClaudeForAccounts { param($Accounts) $script:ClaudeAccounts = @($Accounts).Count; return @("  a, b, c : deja a jour", $script:Ink.Dim) }

  $script:FakeInstalled = $true
  $script:FakeLatest = $null
  $script:FakeInstallError = $null
  $script:QuitOnFind = $false
  Assert-Null (Invoke-Startup $true $true) "demarrage : Echap quitte le menu"
  Assert-Equal "Mise a jour de clm|Mise a jour de Claude Code|menu" ($script:Screens -join "|") "demarrage : clm, puis Claude Code, puis les comptes"
  Assert-Equal "Find-ClmUpdate" ($script:Loads -join "|") "demarrage : clm a jour, rien installe"
  Assert-Equal 3 $script:ClaudeAccounts "demarrage : Claude Code mis a jour pour tous les comptes"
  Assert-Equal "  a, b, c : deja a jour" $script:MenuState.Msg[0] "demarrage : resultat de Claude Code affiche dans le menu"
  Assert-True $script:MenuUpdated "demarrage : Claude Code pas relance en mode texte"
  Assert-True (-not $script:ClmUpdated) "demarrage : clm a jour, pas de redemarrage"

  $script:FakeLatest = [PSCustomObject]@{ Sha = ("c" * 40); Time = 5; Number = 0 }
  Assert-Null (Invoke-Startup $true $true) "nouvelle version de clm : menu jamais ouvert"
  Assert-Equal "Mise a jour de clm" ($script:Screens -join "|") "nouvelle version de clm : ni Claude Code ni comptes avant le redemarrage"
  Assert-Equal "Find-ClmUpdate|Install-ClmVersion" ($script:Loads -join "|") "nouvelle version de clm : installee"
  Assert-Equal ("c" * 40) $script:InstallItem.Sha "nouvelle version de clm : celle trouvee"
  Assert-True ($script:WorkPage.Text -like "nouvelle version de clm (ccccccc du *)") "nouvelle version de clm : affichee"
  Assert-True $script:ClmUpdated "nouvelle version de clm : redemarrage demande"
  Assert-True (-not $script:UiOn) "nouvelle version de clm : ecran rendu avant le redemarrage"

  $script:FakeInstallError = "disque plein"
  $null = Invoke-Startup $true $true
  Assert-Equal "Mise a jour de clm|Mise a jour de Claude Code|menu" ($script:Screens -join "|") "installation de clm ratee : la suite continue"
  Assert-Equal "  mise a jour de clm impossible : disque plein   a, b, c : deja a jour" $script:MenuState.Msg[0] "installation de clm ratee : erreur puis resultat de Claude Code"
  Assert-Equal $script:Ink.Alert $script:MenuState.Msg[1] "installation de clm ratee : couleur d'alerte"
  Assert-True (-not $script:ClmUpdated) "installation de clm ratee : pas de redemarrage"
  Assert-Equal "  mise a jour de clm impossible : x" (Add-ClmFailure @("", $script:Ink.Dim) "x")[0] "installation de clm ratee sans autre message"
  $script:FakeInstallError = $null

  $script:QuitOnFind = $true
  Assert-Null (Invoke-Startup $true $true) "Ctrl+C pendant la recherche : sortie"
  Assert-Equal "Find-ClmUpdate" ($script:Loads -join "|") "Ctrl+C pendant la recherche : rien installe"
  Assert-Equal "Mise a jour de clm" ($script:Screens -join "|") "Ctrl+C pendant la recherche : ni Claude Code ni comptes"
  Assert-True (-not $script:ClmUpdated) "Ctrl+C pendant la recherche : pas de redemarrage"
  $script:QuitOnFind = $false
  $script:FakeLatest = $null

  $null = Invoke-Startup $true $false
  Assert-Equal "Mise a jour de Claude Code|menu" ($script:Screens -join "|") "apres redemarrage : Claude Code puis les comptes"
  $script:FakeInstalled = $false
  $null = Invoke-Startup $false $true
  Assert-Equal "menu" ($script:Screens -join "|") "clm hors de son dossier d'installation, sans mise a jour : comptes directement"
  Assert-Equal 0 $script:Loads.Count "clm hors de son dossier d'installation : aucune recherche"
} finally {
  foreach ($n in $startupMocked) { Set-Item -Path ("function:" + $n) -Value $startupKept[$n] }
  $script:DriveJob = $null
  $script:UiKeys.Clear()
  $script:ClmCheck = $null
  $script:MenuRestart = $false
  $script:ClmUpdated = $false
  $script:UiQuit = $false
  $script:UiProgress = $null
  $script:WorkPage = $null
}
