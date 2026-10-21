$choiceSaved = @($script:SyncChoicePath, $script:SyncChoiceLockPath, $script:SyncChoiceWaitMs)
$script:SyncChoicePath = Join-Path $script:Sandbox "choice.json"
$script:SyncChoiceLockPath = Join-Path $script:Sandbox "choice.lock"
$script:SyncChoiceWaitMs = 0

$c = Read-SyncChoice
Assert-True (Test-SkillChecked $c "outil") "sans fichier : skill coche"
Assert-True (Test-McpChecked $c "m" $script:OsName) "sans fichier : MCP du meme systeme coche"
Assert-True (-not (Test-McpChecked $c "m" "Systeme9")) "sans fichier : MCP d'un autre systeme decoche"

$null = Update-SyncChoice { param($x) Set-ChoiceCheck $x "skills" "outil" $false $true; Set-ChoiceCheck $x "mcp" "loin" $true $false; Set-ChoiceCheck $x "mcp" "Loin" $false $false }
$c = Read-SyncChoice
Assert-True (-not (Test-SkillChecked $c "outil")) "skill decoche garde"
Assert-True (Test-SkillChecked $c "Outil") "noms sensibles a la casse"
Assert-True (Test-McpChecked $c "loin" "Systeme9") "MCP d'un autre systeme coche a la main"
Assert-Equal 0 ([IO.File]::ReadAllText($script:SyncChoicePath).Split([string[]]@('"Loin"'), "None").Count - 1) "case remise a son defaut : rien ecrit"

$null = Update-SyncChoice { param($x) Set-ChoiceCheck $x "skills" "outil" $true $true }
Assert-True (Test-SkillChecked (Read-SyncChoice) "outil") "skill recoche"

$null = Update-SyncChoice { param($x) Add-EraseRequest $x "mcp" "loin"; Add-EraseRequest $x "mcp" "loin"; Add-EraseRequest $x "skills" "vieux" }
$c = Read-SyncChoice
Assert-Equal "loin" ($c.Erase.mcp -join ",") "demande d'effacement gardee une fois"
Assert-True (-not $c.mcp.ContainsKey("loin")) "effacement : case oubliee"
Assert-Equal "vieux" ($c.Erase.skills -join ",") "effacement de skill garde"
$null = Update-SyncChoice { param($x) Remove-EraseRequests $x "mcp" @("loin") }
Assert-Equal 0 (Read-SyncChoice).Erase.mcp.Count "effacement fait : demande retiree"

[IO.File]::WriteAllText($script:SyncChoicePath, '{"skills": {"a": "non", "b": false}, "mcp": [1], "erase": {"skills": [3, "", "c"]}}')
$c = Read-SyncChoice
Assert-Equal "b" (@($c.skills.Keys) -join ",") "fichier abime : seules les cases valides gardees"
Assert-Equal 0 $c.mcp.Count "fichier abime : MCP ignores"
Assert-Equal "c" ($c.Erase.skills -join ",") "fichier abime : demandes valides gardees"
[IO.File]::WriteAllText($script:SyncChoicePath, "pas du json")
Assert-Equal 0 (Read-SyncChoice).skills.Count "fichier illisible : choix vide"

$held = [IO.File]::Open($script:SyncChoiceLockPath, "OpenOrCreate", "ReadWrite", "None")
$err = ""
try { $null = Update-SyncChoice { param($x) Set-ChoiceCheck $x "skills" "z" $false $true } } catch { $err = $_.Exception.Message }
$held.Dispose()
Assert-Equal $script:SyncChoiceBusyText $err "verrou pris : ecriture refusee"

Remove-Item -LiteralPath $script:SyncChoicePath, $script:SyncChoiceLockPath -Force -ErrorAction SilentlyContinue
$script:SyncChoicePath, $script:SyncChoiceLockPath, $script:SyncChoiceWaitMs = $choiceSaved
