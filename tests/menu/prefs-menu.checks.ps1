. (Join-Path $PSScriptRoot "prefs-fakes.ps1")

try {
  $cat = New-PrefsFixture
  $cat.Waiting = [string[]]@("vieux", "mac")
  Assert-Equal (Get-ClmText "sync.prefs.sub.waiting" @("vieux, mac")) (Get-PrefsSub $cat) "sous-titre : PC pas a jour"
  $cat.Waiting = [string[]]@()
  Assert-Equal (Get-ClmText "sync.prefs.sub.perPc") (Get-PrefsSub $cat) "sous-titre : mode par PC pas encore actif"
  $cat.PerPc = $true
  Assert-Equal (Get-ClmText "sync.prefs.sub.checked") (Get-PrefsSub $cat) "sous-titre : mode par PC"
  $offAll = New-PrefsAll "skills" (Get-ClmText "sync.prefs.all.skills") @((New-PrefsItem @{ Kind = "skills"; Key = "a"; Label = "a"; Tag = ""; On = $true; Erasing = $false }), (New-PrefsItem @{ Kind = "skills"; Key = "b"; Label = "b"; Tag = ""; On = $false; Erasing = $false }), (New-PrefsItem @{ Kind = "skills"; Key = "c"; Label = "c"; Tag = ""; On = $true; Erasing = $false }))
  Assert-Equal ((Get-PrefsOffWarn "skills") + "|  " + (Get-ClmText "sync.prefs.manyOff" @(2))) ((Get-PrefsOffLines $offAll) -join "|") "tout decocher : seules les cases cochees comptent"
  Assert-True ((Get-PrefsOffLines (New-PrefsItem @{ Kind = "globals"; Key = "g"; Label = "g"; Tag = ""; On = $true; Erasing = $false }) "B")[0].Contains("B")) "decocher pour un autre PC : son nom dit"

  $script:PrefsDrive = $false
  Assert-Equal (Get-ClmText "sync.prefs.needDrive") (Show-PrefsMenu) "sans Drive : ecran refuse"
  $script:PrefsDrive = $true
  $script:PrefsSyncs = 0
  Save-SyncCatalog $cat
  $null = New-SandboxFile ".claude-prefs/$($script:DriveHeldName)" '{"mcpServers": {"roblox": {"command": "r"}}}'
  Assert-Equal (Get-ClmText "sync.prefs.unchanged") (Invoke-PrefsKeys @([ConsoleKey]::DownArrow, [ConsoleKey]::UpArrow, "q")) "q sans changement"
  Assert-Equal 0 $script:PrefsSyncs "sans changement : pas de synchro"
  Assert-True ([string]($script:PrefsShown | ForEach-Object { $_ | ForEach-Object { $_[0] } }) -match "roblox") "MCP global du compte affiche"
  $script:PrefsSeen = ""
  Assert-Equal (Get-ClmText "sync.prefs.unchanged") (Invoke-PrefsKeys @([ConsoleKey]::DownArrow, [ConsoleKey]::DownArrow, [ConsoleKey]::Spacebar, "n", [ConsoleKey]::Escape)) "Espace puis n : case gardee"
  Assert-True ($script:PrefsSeen.Contains((Get-ClmText "sync.prefs.uncheck.ask" @("beta"))) -and $script:PrefsSeen.Contains((Get-PrefsOffWarn "skills").Trim())) "decocher : ce qui quitte ce PC est dit avant"
  $msg = Invoke-PrefsKeys @([ConsoleKey]::DownArrow, [ConsoleKey]::DownArrow, [ConsoleKey]::Spacebar, "o", [ConsoleKey]::Escape)
  Assert-Equal (Get-ClmText "sync.prefs.saved") $msg "Espace puis o : reglage enregistre"
  Assert-True ((Read-SyncChoice).skills["beta"] -eq $false) "Espace : skill beta decoche dans le fichier"
  Assert-Equal 1 $script:PrefsSyncs "reglage change : synchro lancee"
  Assert-Equal (Get-ClmText "sync.prefs.unchanged") (Invoke-PrefsKeys @([ConsoleKey]::Delete, "o", [ConsoleKey]::Escape)) "Suppr sur tout un groupe : sans effet"
  Assert-Equal (Get-ClmText "sync.prefs.unchanged") (Invoke-PrefsKeys @([ConsoleKey]::DownArrow, [ConsoleKey]::Delete, "n", [ConsoleKey]::Escape)) "Suppr puis n : rien efface"
  $null = Invoke-PrefsKeys @([ConsoleKey]::DownArrow, [ConsoleKey]::Delete, "o", [ConsoleKey]::Escape)
  Assert-Equal "alpha" ((Read-SyncChoice).Erase.skills -join ",") "Suppr puis o : effacement demande"
  $cat.Pcs["B"] = New-PcContent
  $cat.Pcs["B"].Os = $script:OsName
  Save-SyncCatalog $cat
  Assert-Equal (Get-ClmText "sync.prefs.unchanged") (Invoke-PrefsKeys @([ConsoleKey]::RightArrow, [ConsoleKey]::Spacebar, [ConsoleKey]::Escape)) "fleche droite : PC sans clm a jour, rien a cocher"
  Assert-True ((Get-PrefsShown).Contains((Get-ClmText "sync.prefs.pc.old")) -and (Get-PrefsShown).Contains("MOI (" + (Get-ClmText "sync.prefs.thisPc") + ")")) "PC sans clm a jour : explication et liste des PC"
  $script:PrefsSyncs = 0
  $msg = Invoke-PrefsKeys @([ConsoleKey]::LeftArrow, [ConsoleKey]::DownArrow, [ConsoleKey]::Spacebar, "o", [ConsoleKey]::Delete, "o", [ConsoleKey]::Escape)
  Assert-Equal (Get-ClmText "sync.prefs.saved") $msg "fleche gauche : dernier PC, case decochee pour lui"
  Assert-True (-not (Read-SyncChoice).Asks["B"].skills["alpha"].On) "demande enregistree pour l'autre PC"
  Assert-True ((Get-PrefsShown).Contains((Get-ClmText "sync.prefs.pc.wait")) -and (Get-PrefsShown).Contains((Get-ClmText "sync.prefs.pc.title" @("B")))) "case de l'autre PC en attente"
  Assert-Equal "alpha" ((Read-SyncChoice).Erase.skills -join ",") "Suppr sur un autre PC : sans effet"
  $null = Invoke-PrefsKeys @([ConsoleKey]::LeftArrow, [ConsoleKey]::DownArrow, [ConsoleKey]::Spacebar, [ConsoleKey]::Escape)
  Assert-True (-not (Read-SyncChoice).Asks.ContainsKey("B")) "case remise : demande retiree"
  Remove-Item -LiteralPath $script:SyncCatalogPath, (Join-Path $script:Sandbox "prefs-test") -Recurse -Force
  [IO.File]::WriteAllText((Join-Path $script:Sandbox ".claude-prefs/$($script:DriveHeldName)"), "{}")
  Remove-Item -LiteralPath $script:SyncChoicePath -Force
  Assert-Equal (Get-ClmText "sync.prefs.noneToShow") (Invoke-PrefsKeys @("x")) "rien a regler : ecran vide"
} finally {
  Restore-PrefsFakes
}
