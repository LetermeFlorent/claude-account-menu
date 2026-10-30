. (Join-Path $bin "menu/manage/claude-menu-prefs.ps1")
. (Join-Path $bin "cli/claude-cli.ps1")

$cliPrefsPaths = @($script:SyncCatalogPath, $script:SyncChoicePath, $script:SyncChoiceLockPath, $script:SyncChoiceWaitMs, $script:SkillsRoot, $script:DriveConfigPath)
$script:SyncCatalogPath = Join-Path $script:Sandbox "cli-catalog.json"
$script:SyncChoicePath = Join-Path $script:Sandbox "cli-choice.json"
$script:SyncChoiceLockPath = Join-Path $script:Sandbox "cli-choice.lock"
$script:SyncChoiceWaitMs = 0
$script:SkillsRoot = "cli-test/skills"
$script:DriveConfigPath = Join-Path $script:Sandbox "cli-drive.json"
$cliPrefsMocked = @("Invoke-DriveCliSync", "Get-GlobalNames")
$cliPrefsKept = @{}
foreach ($n in $cliPrefsMocked) { $cliPrefsKept[$n] = (Get-Item ("function:" + $n)).ScriptBlock }

function Invoke-PrefsCli {
  param([object[]]$ArgList)
  return Invoke-CliCommand (Get-CliCommand $ArgList) $ArgList 6>$null
}

function Invoke-DriveCliSync { param([bool]$Force) $script:CliPrefsSyncs++; return 0 }
function Get-GlobalNames { param($Accs) return ,[string[]]@("roblox", "blender") }

try {
  $script:CliPrefsSyncs = 0
  Assert-Equal (Get-ClmText "drive.off") ((Get-CliDriveLines) -join "|") "etat Drive : non connecte"
  Assert-Equal 1 (Invoke-PrefsCli @("--prefs")) "--prefs sans Drive : echec"
  Assert-Equal 1 (Invoke-PrefsCli @("--prefs-off", "roblox")) "--prefs-off sans Drive : echec"

  $at = [DateTimeOffset]::new(2026, 10, 21, 8, 30, 0, [TimeSpan]::Zero).ToUnixTimeSeconds()
  $atText = [DateTimeOffset]::FromUnixTimeSeconds($at).LocalDateTime.ToString("dd/MM/yyyy HH:mm")
  Save-DriveConfig @{ refreshToken = "r"; auto = $false; pc = "BUREAU"; lastSync = $at }
  $want = (Get-ClmText "drive.status.connected") + "|" + (Get-ClmText "drive.status.pc" @("BUREAU")) + "|" + (Get-ClmText "drive.status.auto" @((Get-ClmText "drive.status.auto.off"))) + "|" + (Get-ClmText "drive.status.last" @($atText)) + "|" + (Get-ClmText "drive.status.key" @((Get-ClmText "drive.status.key.missing"))) + "|" + (Get-ClmText "drive.status.mcp.perpc.later")
  Assert-Equal $want ((Get-CliDriveLines) -join "|") "etat Drive : PC, synchro auto, derniere synchro, phrase, MCP"
  Save-SyncKeys (New-SyncKeys ([byte[]](1..32)) ([byte[]](1..16)) 600000)
  Assert-True ((Get-CliDriveLines) -contains (Get-ClmText "drive.status.key" @((Get-ClmText "drive.status.key.stored")))) "etat Drive : phrase de synchro enregistree"
  Remove-SyncKeys
  Assert-Equal 0 (Invoke-PrefsCli @("--drive-status")) "--drive-status : reussi"

  $cat = New-SyncCatalog
  $cat.Skills = [string[]]@("alpha")
  $cat.Pcs["A"] = New-PcContent
  $cat.Pcs["A"].Mcp["|loin"] = @{ At = 5; Deleted = $false; Os = "Autre"; Def = "{}" }
  $cat.Pcs["A"].Mcp["|outil"] = @{ At = 5; Deleted = $false; Os = $script:OsName; Def = "{}" }
  $cat.Pcs["A"].Mcp["Documents/p|outil"] = @{ At = 5; Deleted = $false; Os = $script:OsName; Def = "{}" }
  $cat.PerPc = $true
  Save-SyncCatalog $cat
  $os = $script:OsName
  $want = @(((Get-ClmText "sync.prefs.title") + ", " + (Get-ClmText "drive.status.mcp.perpc")), (Get-ClmText "sync.prefs.head.skills"), ("  [x] skill:*  " + (Get-ClmText "sync.prefs.all.skills") + "  " + (Get-ClmText "sync.prefs.checkedCount" @(1, 1))), "  [x] skill:alpha", (Get-ClmText "sync.prefs.head.mcp"), ("  [-] mcp:*  " + (Get-ClmText "sync.prefs.all.mcp") + "  " + (Get-ClmText "sync.prefs.checkedCount" @(4, 5))), ("  [x] global:blender  " + (Get-ClmText "sync.prefs.thisPc")), ("  [ ] mcp:|loin  " + (Get-ClmText "sync.prefs.home") + ", Autre"), ("  [x] mcp:Documents/p|outil  p, " + $os), ("  [x] mcp:|outil  " + (Get-ClmText "sync.prefs.home") + ", " + $os), ("  [x] global:roblox  " + (Get-ClmText "sync.prefs.thisPc")))
  Assert-Equal ($want -join "`n") ((Get-CliPrefsLines) -join "`n") "--prefs : cases et ids par categorie"

  Assert-Equal 1 (Invoke-PrefsCli @("--prefs-off", "outil")) "nom porte par deux MCP : refuse"
  Assert-Equal 1 (Invoke-PrefsCli @("--prefs-off", "absent")) "id inconnu : refuse"
  Assert-Equal 1 (Invoke-PrefsCli @("--prefs-off")) "sans id : refuse"
  Assert-Equal 0 $script:CliPrefsSyncs "refus : pas de synchro"
  Assert-True (-not (Test-Path -LiteralPath $script:SyncChoicePath)) "refus : reglages non ecrits"

  Assert-Equal 0 (Invoke-PrefsCli @("--prefs-off", "global:roblox", "blender", "mcp:|outil")) "--prefs-off : reussi"
  $ch = Read-SyncChoice
  Assert-True ($ch.globals["roblox"] -eq $false -and $ch.globals["blender"] -eq $false -and $ch.mcp["|outil"] -eq $false) "--prefs-off : cases decochees dans le fichier"
  Assert-Equal 1 $script:CliPrefsSyncs "--prefs-off : synchro lancee"
  Assert-Equal 0 (Invoke-PrefsCli @("--prefs-on", "loin")) "--prefs-on : nom unique"
  Assert-True ((Read-SyncChoice).mcp["|loin"] -eq $true) "--prefs-on : MCP d'un autre systeme coche"
  Assert-Equal 0 (Invoke-PrefsCli @("--prefs-on", "global:roblox")) "--prefs-on : global recoche"
  Assert-True (-not (Read-SyncChoice).globals.ContainsKey("roblox")) "--prefs-on : global revenu au defaut"

  Assert-Equal 1 (Invoke-PrefsCli @("--prefs-erase", "skill:alpha")) "--prefs-erase sans --yes : refuse"
  Assert-Equal 0 (Read-SyncChoice).Erase.skills.Count "--prefs-erase sans --yes : rien demande"
  Assert-Equal 0 (Invoke-PrefsCli @("--prefs-erase", "skill:alpha", "--yes")) "--prefs-erase --yes : reussi"
  Assert-Equal "alpha" ((Read-SyncChoice).Erase.skills -join ",") "--prefs-erase : effacement demande"
  Assert-True ((Get-CliPrefsLines) -contains ("  [ ] skill:alpha  " + (Get-ClmText "sync.prefs.erasing"))) "--prefs : effacement en attente affiche"
  Assert-Equal 0 (Invoke-PrefsCli @("--prefs-on", "alpha")) "--prefs-on sur un effacement : reussi"
  $ch = Read-SyncChoice
  Assert-True ($ch.Erase.skills.Count -eq 0 -and -not $ch.skills.ContainsKey("alpha")) "--prefs-on : effacement annule, case au defaut"

  Assert-Equal 1 (Invoke-PrefsCli @("--prefs-off", "*")) "* seul : deux groupes, refuse"
  Assert-Equal 1 (Invoke-PrefsCli @("--prefs-erase", "mcp:*", "--yes")) "groupe entier a effacer : refuse"
  Assert-Equal 1 (Invoke-PrefsCli @("--prefs-off", "global:*")) "global:* : plus de groupe a part pour les MCP globaux"
  Assert-True ((Get-CliPrefsLines) -contains ("  [-] mcp:*  " + (Get-ClmText "sync.prefs.all.mcp") + "  " + (Get-ClmText "sync.prefs.checkedCount" @(3, 5)))) "--prefs : groupe en partie coche"
  Assert-Equal 0 (Invoke-PrefsCli @("--prefs-off", "mcp:*")) "--prefs-off mcp:* : reussi"
  $ch = Read-SyncChoice
  Assert-True ($ch.globals["roblox"] -eq $false -and $ch.globals["blender"] -eq $false -and $ch.mcp["|outil"] -eq $false -and -not $ch.mcp.ContainsKey("|loin")) "--prefs-off mcp:* : MCP locaux et globaux decoches"
  Assert-Equal 0 (Invoke-PrefsCli @("--prefs-on", "mcp:*")) "--prefs-on mcp:* : reussi"
  $ch = Read-SyncChoice
  Assert-True ($ch.mcp["|loin"] -eq $true -and -not $ch.mcp.ContainsKey("|outil") -and -not $ch.mcp.ContainsKey("Documents/p|outil") -and $ch.globals.Count -eq 0) "--prefs-on mcp:* : tous les MCP coches"
  Assert-Equal 7 $script:CliPrefsSyncs "chaque changement lance la synchro"
} finally {
  foreach ($n in $cliPrefsMocked) { Set-Item -Path ("function:" + $n) -Value $cliPrefsKept[$n] }
  Remove-Item -LiteralPath $script:SyncCatalogPath, $script:SyncChoicePath, $script:SyncChoiceLockPath, $script:DriveConfigPath -Force -ErrorAction SilentlyContinue
  $script:SyncCatalogPath, $script:SyncChoicePath, $script:SyncChoiceLockPath, $script:SyncChoiceWaitMs, $script:SkillsRoot, $script:DriveConfigPath = $cliPrefsPaths
}
