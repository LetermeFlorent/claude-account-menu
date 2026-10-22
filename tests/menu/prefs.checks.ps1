. (Join-Path $bin "claude-menu-prefs.ps1")

$prefsPaths = @($script:SyncCatalogPath, $script:SyncChoicePath, $script:SyncChoiceLockPath, $script:SyncChoiceWaitMs, $script:SkillsRoot, $script:UiRows)
$script:SyncCatalogPath = Join-Path $script:Sandbox "prefs-catalog.json"
$script:SyncChoicePath = Join-Path $script:Sandbox "prefs-choice.json"
$script:SyncChoiceLockPath = Join-Path $script:Sandbox "prefs-choice.lock"
$script:SyncChoiceWaitMs = 0
$script:SkillsRoot = "prefs-test/skills"
$prefsMocked = @("Show-UiRows", "Update-UiTick", "Test-DriveConnected", "Request-DriveSync", "Get-Accounts", "Get-DrivePcName")
$prefsKept = @{}
foreach ($n in $prefsMocked) { $prefsKept[$n] = (Get-Item ("function:" + $n)).ScriptBlock }

function Get-PrefsText {
  param($Lines)
  return (@($Lines | ForEach-Object { if ($_.Head) { "[" + $_.Label + "]" } else { $_.Label + ":" + [int]$_.On + [int]$_.Erasing } }) -join " ")
}

function Invoke-PrefsKeys {
  param([object[]]$Keys)
  $script:UiKeys.Clear()
  foreach ($k in $Keys) {
    $c = [char]0
    if ($k -is [string]) { $c = [char]$k; $k = [ConsoleKey]::D2 }
    if ($k -eq [ConsoleKey]::Spacebar) { $c = " " }
    $script:UiKeys.Enqueue((New-Object System.ConsoleKeyInfo $c, $k, $false, $false, $false))
  }
  return Show-PrefsMenu
}

function Show-UiRows { param($Rows, [double]$Now, $RowFades = $null) $script:PrefsShown = $Rows }
function Update-UiTick { param([double]$Now, [bool]$Busy) return $false }
function Test-DriveConnected { return $script:PrefsDrive }
function Request-DriveSync { param($Job) $script:PrefsSyncs++ }
function Get-Accounts { return @([PSCustomObject]@{ Label = "p"; Dir = ".claude-prefs" }) }
function Get-DrivePcName { return "MOI" }
function Get-PrefsShown { return [string]($script:PrefsShown | ForEach-Object { $_ | ForEach-Object { $_[0] } }) }

try {
  $cat = New-SyncCatalog
  $cat.Skills = [string[]]@("alpha")
  $cat.Pcs["A"] = New-PcContent
  $cat.Pcs["A"].Mcp["|loin"] = @{ At = 5; Deleted = $false; Os = "Autre"; Def = "{}" }
  $cat.Pcs["A"].Mcp["|ici"] = @{ At = 5; Deleted = $false; Os = $script:OsName; Def = "{}" }
  $cat.Pcs["A"].Mcp["|parti"] = @{ At = 5; Deleted = $true; Os = $script:OsName; Def = "" }
  $cat.Pcs["A"].Mcp["Documents/p|outil"] = @{ At = 5; Deleted = $false; Os = $script:OsName; Def = "{}" }
  $cat.Parked["blender"] = "{}"
  $null = New-SandboxFile "prefs-test/skills/beta/SKILL.md" "b"
  $choice = New-SyncChoice
  $choice.globals["blender"] = $false
  Add-EraseRequest $choice "mcp" "|vieux"
  $lines = Get-PrefsLines $choice $cat @("roblox")
  $want = "[Skills] tous les skills:10 alpha:10 beta:10 [MCP] tous les MCP:00 blender:00 ici:10 loin:00 outil:10 roblox:10 vieux:01"
  Assert-Equal $want (Get-PrefsText $lines) "reglages : skills puis MCP, une case pour tout le groupe"
  Assert-Equal "perso, Autre" $lines[8].Tag "reglages : MCP du dossier perso, systeme affiche"
  Assert-Equal ("p, " + $script:OsName) $lines[9].Tag "reglages : MCP d'un projet, nom du dossier"
  Assert-Equal "ce PC" $lines[6].Tag "reglages : MCP global de ce PC"
  Assert-Equal "perso" $lines[11].Tag "reglages : MCP a effacer hors catalogue, sans systeme"

  Set-PrefsCheck $choice $lines[2]
  Assert-True ($choice.skills["alpha"] -eq $false) "skill decoche"
  Set-PrefsCheck $choice (Get-PrefsLines $choice $cat @("roblox"))[2]
  Assert-True (-not $choice.skills.ContainsKey("alpha")) "skill recoche : retour au defaut"
  Set-PrefsCheck $choice $lines[8]
  Assert-True ($choice.mcp["|loin"] -eq $true) "MCP d'un autre systeme coche a la main"
  Set-PrefsCheck $choice $lines[7]
  Assert-True ($choice.mcp["|ici"] -eq $false) "MCP du meme systeme decoche"
  Set-PrefsCheck $choice $lines[11]
  Assert-Equal 0 $choice.Erase.mcp.Count "Espace sur un effacement en attente : annule"
  Assert-True (-not $choice.mcp.ContainsKey("|vieux")) "effacement annule : case inchangee"
  Set-PrefsCheck $choice $lines[10]
  Assert-True ($choice.globals["roblox"] -eq $false) "MCP global decoche"

  $group = New-SyncChoice
  $group.globals["blender"] = $false
  Add-EraseRequest $group "mcp" "|vieux"
  $l = Get-PrefsLines $group $cat @("roblox")
  Assert-True ($l[1].On -and -not $l[1].Mixed -and $l[1].Tag -eq "coches : 2 sur 2") "tous les skills : tout coche"
  Assert-True ($l[5].Mixed -and -not $l[5].On -and $l[5].Tag -eq "coches : 3 sur 5") "tous les MCP : globaux compris, effacement en attente pas compte"
  Set-PrefsCheck $group $l[5]
  Assert-True ($group.mcp["|loin"] -eq $true -and -not $group.mcp.ContainsKey("|ici") -and $group.globals.Count -eq 0) "tous les MCP en partie coches : tout coche, globaux compris"
  $l = Get-PrefsLines $group $cat @("roblox")
  Assert-True ($l[5].On -and -not $l[5].Mixed) "tous les MCP : tout coche"
  Set-PrefsCheck $group $l[5]
  Assert-True ($group.mcp["|ici"] -eq $false -and -not $group.mcp.ContainsKey("|loin") -and $group.mcp["Documents/p|outil"] -eq $false) "tous les MCP coches : MCP locaux decoches"
  Assert-True ($group.globals["blender"] -eq $false -and $group.globals["roblox"] -eq $false) "tous les MCP coches : MCP globaux decoches"
  Assert-Equal "|vieux" ($group.Erase.mcp -join ",") "tous les MCP : effacement en attente garde"
  Set-PrefsCheck $group (Get-PrefsLines $group $cat @("roblox"))[1]
  Assert-True ($group.skills["alpha"] -eq $false -and $group.skills["beta"] -eq $false) "tous les skills coches : tout decoche"
  Assert-Equal 0 @((Get-PrefsLines (New-SyncChoice) (New-SyncCatalog) @()) | Where-Object { $_.All -and $_.Kind -eq "mcp" }).Count "aucun MCP : pas de case pour le groupe"
  $script:UiRows = 40
  $l = Get-PrefsLines $group $cat @("roblox")
  $shown = @(foreach ($r in (Get-PrefsRows $l 5)) { (@($r) | ForEach-Object { $_[0] }) -join "" })
  Assert-True ($shown[5].Contains("tous les MCP") -and $shown[5].Contains("coches : 0 sur 5")) "case du groupe : nom et compte"
  Assert-True ($shown[9].Contains("outil") -and $shown[9].EndsWith("p, " + $script:OsName)) "MCP : origine a droite"

  Assert-Equal 1 (Move-PrefsSel $lines -1 1) "premiere case : titre saute"
  Assert-Equal 5 (Move-PrefsSel $lines 3 1) "case suivante : titre de groupe saute"
  Assert-Equal 11 (Move-PrefsSel $lines 1 -1) "case precedente : tour par la fin"
  Assert-Equal 0 (Move-PrefsSel @((New-PrefsHead "a")) 0 1) "que des titres : selection gardee"
  Assert-Equal 9 (Find-PrefsLine $lines $lines[9]) "case retrouvee apres reconstruction"
  Assert-Equal 1 (Find-PrefsLine $lines (New-PrefsItem "mcp" "|absent" "absent" "" $false $false)) "case disparue : premiere case"

  $script:UiRows = 30
  Assert-Equal "0 10" ((Get-PrefsWindow 10 3) -join " ") "liste courte : tout visible"
  Assert-Equal "0 16" ((Get-PrefsWindow 40 0) -join " ") "liste longue : debut"
  Assert-Equal "12 28" ((Get-PrefsWindow 40 20) -join " ") "liste longue : selection centree"
  Assert-Equal "24 40" ((Get-PrefsWindow 40 39) -join " ") "liste longue : fin"
  $script:UiRows = 5
  Assert-Equal "0 4" ((Get-PrefsWindow 40 0) -join " ") "fenetre minuscule : quatre lignes"
  $many = @(1..30 | ForEach-Object { New-PrefsItem "skills" ("s" + $_) ("s" + $_) "" $true $false })
  $script:UiRows = 30
  $rows = Get-PrefsRows $many 20
  Assert-Equal 18 $rows.Count "liste longue : fleches en plus des lignes"
  Assert-Equal ("    " + $script:UpArrow) $rows[0][0][0] "liste longue : fleche du haut"

  $cat.Waiting = [string[]]@("vieux", "mac")
  Assert-Equal "MCP envoyes en entier tant que ces PC n'ont pas clm a jour : vieux, mac" (Get-PrefsSub $cat) "sous-titre : PC pas a jour"
  $cat.Waiting = [string[]]@()
  Assert-Equal "MCP reglables par PC apres la prochaine synchro Drive" (Get-PrefsSub $cat) "sous-titre : mode par PC pas encore actif"
  $cat.PerPc = $true
  Assert-Equal "case cochee : synchronise sur ce PC" (Get-PrefsSub $cat) "sous-titre : mode par PC"

  $script:PrefsDrive = $false
  Assert-Equal "reglages de synchro : connecte d'abord le Drive avec y" (Show-PrefsMenu) "sans Drive : ecran refuse"
  $script:PrefsDrive = $true
  $script:PrefsSyncs = 0
  Save-SyncCatalog $cat
  $null = New-SandboxFile ".claude-prefs/$($script:DriveHeldName)" '{"mcpServers": {"roblox": {"command": "r"}}}'
  Assert-Equal "reglages de synchro inchanges" (Invoke-PrefsKeys @([ConsoleKey]::DownArrow, [ConsoleKey]::UpArrow, "q")) "q sans changement"
  Assert-Equal 0 $script:PrefsSyncs "sans changement : pas de synchro"
  Assert-True ([string]($script:PrefsShown | ForEach-Object { $_ | ForEach-Object { $_[0] } }) -match "roblox") "MCP global du compte affiche"
  $msg = Invoke-PrefsKeys @([ConsoleKey]::DownArrow, [ConsoleKey]::DownArrow, [ConsoleKey]::Spacebar, [ConsoleKey]::Escape)
  Assert-Equal "reglages de synchro enregistres, synchro Drive lancee" $msg "Espace : reglage enregistre"
  Assert-True ((Read-SyncChoice).skills["beta"] -eq $false) "Espace : skill beta decoche dans le fichier"
  Assert-Equal 1 $script:PrefsSyncs "reglage change : synchro lancee"
  Assert-Equal "reglages de synchro inchanges" (Invoke-PrefsKeys @([ConsoleKey]::Delete, "o", [ConsoleKey]::Escape)) "Suppr sur tout un groupe : sans effet"
  Assert-Equal "reglages de synchro inchanges" (Invoke-PrefsKeys @([ConsoleKey]::DownArrow, [ConsoleKey]::Delete, "n", [ConsoleKey]::Escape)) "Suppr puis n : rien efface"
  $null = Invoke-PrefsKeys @([ConsoleKey]::DownArrow, [ConsoleKey]::Delete, "o", [ConsoleKey]::Escape)
  Assert-Equal "alpha" ((Read-SyncChoice).Erase.skills -join ",") "Suppr puis o : effacement demande"
  $cat.Pcs["B"] = New-PcContent
  $cat.Pcs["B"].Os = $script:OsName
  Save-SyncCatalog $cat
  Assert-Equal "reglages de synchro inchanges" (Invoke-PrefsKeys @([ConsoleKey]::RightArrow, [ConsoleKey]::Spacebar, [ConsoleKey]::Escape)) "fleche droite : PC sans clm a jour, rien a cocher"
  Assert-True ((Get-PrefsShown).Contains($script:PrefsPcOld) -and (Get-PrefsShown).Contains("MOI (ce PC)")) "PC sans clm a jour : explication et liste des PC"
  $script:PrefsSyncs = 0
  $msg = Invoke-PrefsKeys @([ConsoleKey]::LeftArrow, [ConsoleKey]::DownArrow, [ConsoleKey]::Spacebar, [ConsoleKey]::Delete, "o", [ConsoleKey]::Escape)
  Assert-Equal "reglages de synchro enregistres, synchro Drive lancee" $msg "fleche gauche : dernier PC, case decochee pour lui"
  Assert-True (-not (Read-SyncChoice).Asks["B"].skills["alpha"].On) "demande enregistree pour l'autre PC"
  Assert-True ((Get-PrefsShown).Contains($script:PrefsPcWait) -and (Get-PrefsShown).Contains($script:PrefsPcTitle + "B")) "case de l'autre PC en attente"
  Assert-Equal "alpha" ((Read-SyncChoice).Erase.skills -join ",") "Suppr sur un autre PC : sans effet"
  $null = Invoke-PrefsKeys @([ConsoleKey]::LeftArrow, [ConsoleKey]::DownArrow, [ConsoleKey]::Spacebar, [ConsoleKey]::Escape)
  Assert-True (-not (Read-SyncChoice).Asks.ContainsKey("B")) "case remise : demande retiree"
  Remove-Item -LiteralPath $script:SyncCatalogPath, (Join-Path $script:Sandbox "prefs-test") -Recurse -Force
  [IO.File]::WriteAllText((Join-Path $script:Sandbox ".claude-prefs/$($script:DriveHeldName)"), "{}")
  Remove-Item -LiteralPath $script:SyncChoicePath -Force
  Assert-Equal "aucun reglage de synchro a montrer" (Invoke-PrefsKeys @("x")) "rien a regler : ecran vide"
} finally {
  foreach ($n in $prefsMocked) { Set-Item -Path ("function:" + $n) -Value $prefsKept[$n] }
  $script:UiKeys.Clear()
  Remove-Item -LiteralPath (Join-Path $script:Sandbox ".claude-prefs"), (Join-Path $script:Sandbox "prefs-test"), $script:SyncCatalogPath, $script:SyncChoicePath, $script:SyncChoiceLockPath -Recurse -Force -ErrorAction SilentlyContinue
  $script:SyncCatalogPath, $script:SyncChoicePath, $script:SyncChoiceLockPath, $script:SyncChoiceWaitMs, $script:SkillsRoot, $script:UiRows = $prefsPaths
}
