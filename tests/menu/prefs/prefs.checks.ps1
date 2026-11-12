. (Join-Path $PSScriptRoot "prefs-fakes.ps1")

try {
  $cat = New-PrefsFixture
  $choice = New-SyncChoice
  $choice.globals["blender"] = $false
  Add-EraseRequest $choice "mcp" "|vieux"
  $lines = Get-PrefsLines $choice $cat @("roblox")
  $want = "[" + (Get-ClmText "sync.prefs.head.skills") + "] " + (Get-ClmText "sync.prefs.all.skills") + ":10 alpha:10 beta:10 [" + (Get-ClmText "sync.prefs.head.mcp") + "] " + (Get-ClmText "sync.prefs.all.mcp") + ":00 blender:00 ici:10 loin:00 outil:10 roblox:10 vieux:01"
  Assert-Equal $want (Get-PrefsText $lines) "reglages : skills puis MCP, une case pour tout le groupe"
  Assert-Equal ((Get-ClmText "sync.prefs.home") + ", Autre") $lines[8].Tag "reglages : MCP du dossier perso, systeme affiche"
  Assert-Equal ("p, " + $script:OsName) $lines[9].Tag "reglages : MCP d'un projet, nom du dossier"
  Assert-Equal (Get-ClmText "sync.prefs.thisPc") $lines[6].Tag "reglages : MCP global de ce PC"
  Assert-Equal (Get-ClmText "sync.prefs.home") $lines[11].Tag "reglages : MCP a effacer hors catalogue, sans systeme"

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
  Assert-True ($l[1].On -and -not $l[1].Mixed -and $l[1].Tag -eq (Get-ClmText "sync.prefs.checkedCount" @(2, 2))) "tous les skills : tout coche"
  Assert-True ($l[5].Mixed -and -not $l[5].On -and $l[5].Tag -eq (Get-ClmText "sync.prefs.checkedCount" @(3, 5))) "tous les MCP : globaux compris, effacement en attente pas compte"
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
} finally {
  Restore-PrefsFakes
}
