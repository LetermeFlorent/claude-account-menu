. (Join-Path (Split-Path -Parent $PSScriptRoot) "fake-drive.ps1")

function Set-ConfigText {
  param([string]$Rel, [string]$Top, [string]$Project)
  $p = ConvertTo-JsonString (ConvertTo-ProjectPath "Documents/p")
  Set-PcFile $Rel ("{`"tips`": 1, `"mcpServers`": {" + $Top + "}, `"projects`": {" + $p + ": {`"x`": 1, `"mcpServers`": {" + $Project + "}}}}")
}

function Get-McpNames {
  param([string]$Rel)
  $m = Read-McpFile (Join-Path $script:HomeDir $Rel)
  if ($null -eq $m) { return "absent" }
  return (@($m.Keys) | Sort-Object) -join ","
}

function Get-ProjectNames {
  param([string]$Rel)
  $text = Get-PcText $Rel
  if ($null -eq $text) { return "absent" }
  $m = Read-ProjectMcp $text
  return (@($m.Keys | Where-Object { $_.StartsWith("Documents/p|") } | ForEach-Object { (Split-McpKey $_).Name }) | Sort-Object) -join ","
}

function Get-PcFileData {
  param([string]$Pc)
  return ConvertFrom-PcData (ConvertFrom-JsonText (Get-FakePcText ($Pc + ".json"))) $false
}

function Invoke-PcSync {
  param([string]$Pc, [string]$Name)
  Use-Pc $Pc
  $r = Invoke-DriveSync
  Assert-True ($r.Ok -and $r.Failed -eq 0) ($Name + " " + $r.Error)
}

$twoAccs = @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" }, [PSCustomObject]@{ Label = "compte2"; Dir = ".claude-c2" })
Use-Pc "MA"
Save-Registry $twoAccs
$null = New-Item -ItemType Directory -Path (Join-Path $script:HomeDir "Documents/p") -Force
Set-ConfigText ".claude.json" '"glob": {"command": "g"}' '"loc": {"command": "a"}'
Set-PcFile ".claude-c2/.claude.json" '{"tips": 1, "mcpServers": {"glob": {"command": "g"}}}'
Set-PcFile ".mcp.json" '{"mcpServers": {"proj": {"command": "p"}}}'
Invoke-PcSync "MA" "premiere synchro par PC"
$ma = Get-PcFileData "MA"
Assert-True ($ma.Mcp.Count -eq 2 -and $ma.Mcp.ContainsKey("Documents/p|loc") -and $ma.Mcp.ContainsKey("|proj")) "MCP locaux de ce PC publies, globaux jamais"
Assert-Equal $script:OsName $ma.Mcp["|proj"].Os "MCP publie avec son systeme"
Assert-True (-not (Get-FakeText ".claude.json").Contains("mcpServers")) "config envoyee sans les MCP"
Assert-Equal "glob" (Get-McpNames ".claude.json") "globaux de ce PC gardes"
Assert-Equal "loc" (Get-ProjectNames ".claude.json") "MCP du projet gardes"
Assert-Equal "loc" (Get-ProjectNames ".claude-c2/.claude.json") "MCP du projet ajoute a l'autre compte"
Assert-True (Read-SyncCatalog).PerPc "mode par PC note"

Use-Pc "MB"
Save-Registry $twoAccs
Set-ConfigText ".claude.json" '"gb": {"command": "h"}' '"own": {"command": "b"}'
Invoke-PcSync "MB" "PC qui rejoint"
Assert-Equal "gb" (Get-McpNames ".claude.json") "PC qui rejoint : globaux jamais recus d'un autre PC"
Assert-Equal "loc,own" (Get-ProjectNames ".claude.json") "PC qui rejoint : ses MCP gardes, ceux du meme systeme ajoutes"
Assert-Equal "proj" (Get-McpNames ".mcp.json") "PC qui rejoint : .mcp.json cree"
Assert-True (Get-PcFileData "MB").Mcp.ContainsKey("Documents/p|own") "PC qui rejoint : son MCP publie"

Invoke-PcSync "MA" "MCP d'un autre PC recu"
Assert-Equal "loc,own" (Get-ProjectNames ".claude.json") "MCP du meme systeme coche par defaut"
Assert-Equal "loc,own" (Get-ProjectNames ".claude-c2/.claude.json") "MCP ajoute a chaque compte"
Assert-Equal "glob" (Get-McpNames ".claude.json") "globaux d'un autre PC jamais recus"

$far = '{"mcp": {"Documents/p|loin": {"at": 5, "os": "Autre", "def": "{\"command\":\"z\"}"}}, "erased": {}}'
$null = Send-FakeSealedPc "MZ.json" $far
Invoke-PcSync "MA" "MCP d'un autre systeme"
Assert-Equal "loc,own" (Get-ProjectNames ".claude.json") "MCP d'un autre systeme decoche par defaut"
$null = Update-SyncChoice { param($c) Set-ChoiceCheck $c "mcp" "Documents/p|loin" $true $false }
Invoke-PcSync "MA" "MCP coche a la main"
Assert-Equal "loc,loin,own" (Get-ProjectNames ".claude.json") "MCP d'un autre systeme coche a la main"

Set-ConfigText ".claude.json" '"glob": {"command": "g"}' '"loc": {"command": "a"}, "loin": {"command":"z"}'
Invoke-PcSync "MA" "MCP retire a la main"
Assert-True (-not (Test-McpChecked (Read-SyncChoice) "Documents/p|own" $script:OsName)) "MCP retire a la main : decoche sur ce PC"
Assert-Equal "loc,loin" (Get-ProjectNames ".claude-c2/.claude.json") "MCP retire a la main : retire des autres comptes"
Invoke-PcSync "MB" "MCP retire sur un autre PC"
Assert-Equal "loc,own" (Get-ProjectNames ".claude.json") "MCP retire sur un autre PC : garde ici"

Use-Pc "MB"
Set-ConfigText ".claude.json" '"gb": {"command": "h"}' '"loc": {"command": "a2"}, "own": {"command": "b"}'
Invoke-PcSync "MB" "MCP modifie"
Invoke-PcSync "MA" "modification recue"
Assert-Equal '{"command":"a2"}' (Read-ProjectMcp (Get-PcText ".claude-c2/.claude.json"))["Documents/p|loc"] "MCP modifie ailleurs : nouvelle definition"

Use-Pc "MB"
$null = Update-SyncChoice { param($c) Add-EraseRequest $c "mcp" "Documents/p|loc" }
Invoke-PcSync "MB" "effacement"
Assert-Equal "own" (Get-ProjectNames ".claude.json") "MCP efface : retire ici"
Assert-Equal 0 (Read-SyncChoice).Erase.mcp.Count "MCP efface : demande retiree"
Invoke-PcSync "MA" "effacement recu"
Assert-Equal "loin" (Get-ProjectNames ".claude.json") "MCP efface ailleurs : retire ici"

$session = Register-DriveSession ([PSCustomObject]@{ Dir = ".claude-c2" })
Use-Pc "MB"
Set-ConfigText ".claude.json" '"gb": {"command": "h"}' '"own": {"command": "b"}, "neuf": {"command": "n"}'
Set-PcFile ".mcp.json" '{"mcpServers": {"proj": {"command": "p"}, "maison": {"command": "m"}}}'
Invoke-PcSync "MB" "nouveau MCP"
Invoke-PcSync "MA" "compte ouvert"
Assert-Equal "loin,neuf" (Get-ProjectNames ".claude.json") "compte ferme : MCP ajoute"
Assert-Equal "maison,proj" (Get-McpNames ".mcp.json") "MCP du dossier perso recu dans .mcp.json"
Assert-Equal "loin" (Get-ProjectNames ".claude-c2/.claude.json") "compte ouvert : config jamais ecrite"
$null = Close-DriveSession $session
Invoke-PcSync "MA" "compte referme"
Assert-Equal "loin,neuf" (Get-ProjectNames ".claude-c2/.claude.json") "compte referme : MCP ajoute"

if ($script:OsName -ne "Linux") {
  Use-Pc "MB"
  $low = ConvertTo-JsonString ((Get-HomeSlash) + "/documents/p")
  Set-PcFile ".claude.json" ("{`"projects`": {" + $low + ": {`"mcpServers`": {`"own`": {`"command`": `"b`"}, `"neuf`": {`"command`": `"n`"}, `"cas`": {`"command`": `"c`"}}}}}")
  Invoke-PcSync "MB" "projet ecrit dans une autre casse"
  Assert-True ((Get-PcFileData "MB").Mcp.ContainsKey("Documents/p|cas")) "autre casse : MCP publie sous le projet connu"
  Assert-True (-not (Get-PcText ".claude.json").Contains("Documents/p")) "autre casse : aucun projet en double"
  Invoke-PcSync "MA" "MCP d'un projet en autre casse recu"
  Assert-Equal "cas,loin,neuf" (Get-ProjectNames ".claude.json") "autre casse : MCP ajoute au projet connu"
}

$null = Send-FakePresence "OLD.json" ([Text.Encoding]::UTF8.GetBytes("{}")) @{ fmt = "2" }
Use-Pc "MB"
Set-ConfigText ".claude.json" '"gb": {"command": "h"}' '"own": {"command": "b"}, "neuf": {"command": "n"}, "pause": {"command": "q"}'
Invoke-PcSync "MB" "ancien PC present"
Assert-True (-not (Get-PcFileData "MB").Mcp.ContainsKey("Documents/p|pause")) "ancien PC present : rien publie"
Assert-True (-not (Read-SyncCatalog).PerPc) "ancien PC present : mode par PC coupe"
Assert-True ((Get-FakeText ".claude.json").Contains("pause")) "ancien PC present : config envoyee entiere"
$script:FakePresence.Remove("OLD.json")
Invoke-PcSync "MA" "config entiere recue"
$maNames = "loin,neuf"
if ($script:OsName -ne "Linux") { $maNames = "cas,loin,neuf" }
Assert-Equal $maNames (Get-ProjectNames ".claude.json") "config entiere recue : MCP de ce PC gardes"
Assert-Equal "glob" (Get-McpNames ".claude.json") "config entiere recue : globaux de ce PC gardes"

Set-PcFile ".claude-c2/.claude.json" '{"mcpServers": {'
Invoke-PcSync "MA" "config illisible"
Assert-Equal '{"mcpServers": {' (Get-PcText ".claude-c2/.claude.json") "config illisible : jamais ecrite"
$script:Fake.Clear()
$script:FakePresence.Clear()
Restore-FakeDrive
. (Join-Path $bin "claude-drive-creds.ps1")
