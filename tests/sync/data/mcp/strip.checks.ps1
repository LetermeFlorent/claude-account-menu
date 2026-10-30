$stripSaved = @($script:HomeDir, $script:McpPerPc)
$script:HomeDir = Join-Path $script:Sandbox "strip"
$null = New-Item -ItemType Directory -Path (Join-Path $script:HomeDir ".claude-c2") -Force
$script:McpPerPc = $false
Assert-True (-not (Test-MachineSettingsPath ".claude.json")) "MCP partages : config envoyee entiere"
$script:McpPerPc = $true
Assert-True (Test-MachineSettingsPath ".claude.json") "MCP par PC : config du premier compte reperee"
Assert-True (Test-MachineSettingsPath ".claude-c2/.claude.json") "MCP par PC : config d'un autre compte reperee"
Assert-True (Test-MachineSettingsPath ".mcp.json") "MCP par PC : .mcp.json repere"
Assert-True (-not (Test-MachineSettingsPath ".claude/projects/p/.claude.json")) "MCP par PC : autre .claude.json ignore"

$proj = ConvertTo-JsonString (ConvertTo-ProjectPath "Documents/p")
$main = Join-Path $script:HomeDir ".claude.json"
[IO.File]::WriteAllText($main, "{`n  `"tips`": 1,`n  `"mcpServers`": {`"a`": {}}`n}")
$sent = [Text.Encoding]::UTF8.GetString((Get-SyncBytes ".claude.json" $main))
Assert-Equal "{`n  `"tips`": 1`n}" $sent "envoi : MCP retires de la config"
Assert-Equal "{`"m`": 1}" ([Text.Encoding]::UTF8.GetString((Get-SyncBytes ".claude/settings.json" (New-SandboxFile "strip/s.json" '{"m": 1}')))) "envoi : reglages sans statusLine inchanges"

[IO.File]::WriteAllText($main, "{`"tips`": 1, `"mcpServers`": {`"a`": {}}, `"projects`": {" + $proj + ": {`"mcpServers`": {`"b`": {}}, `"x`": 1}, `"/ailleurs/p`": {`"mcpServers`": {`"c`": {}}}}}")
$sent = [Text.Encoding]::UTF8.GetString((Get-SyncBytes ".claude.json" $main))
Assert-True (-not $sent.Contains('"a"') -and -not $sent.Contains('"b"')) "envoi : MCP des projets du dossier perso retires"
Assert-True ($sent.Contains('"c"') -and $sent.Contains('"x": 1')) "envoi : projet hors dossier perso et reglages du projet gardes"
$null = ConvertFrom-JsonText $sent

$got = New-SandboxFile "strip/recu.json" "{`"tips`": 2}"
Restore-LocalMachineSettings $got $main ".claude.json"
Assert-Equal "a" (@((Read-McpFile $got).Keys) -join ",") "reception : MCP de ce PC remis"
Assert-Equal "Documents/p|b" (@((Read-ProjectMcp ([IO.File]::ReadAllText($got))).Keys) -join ",") "reception : MCP des projets remis"
$got = New-SandboxFile "strip/recu1.json" ("{`"tips`": 2, `"projects`": {" + $proj + ": {`"x`": 2}}}")
Restore-LocalMachineSettings $got $main ".claude.json"
$text = [IO.File]::ReadAllText($got)
Assert-True ($text.Contains('"x": 2') -and $text.Contains('"b"')) "reception : MCP remis dans le projet recu"
$got = New-SandboxFile "strip/recu2.json" "{`"tips`": 3}"
Restore-LocalMachineSettings $got (Join-Path $script:HomeDir ".claude-c2/.claude.json") ".claude-c2/.claude.json"
Assert-True ([IO.File]::ReadAllText($got).Contains("`"mcpServers`": {`"a`": {}}")) "reception d'un compte neuf : MCP du premier compte"
$got = New-SandboxFile "strip/recu3.json" "{}"
Restore-LocalMachineSettings $got (Join-Path $script:HomeDir ".mcp.json") ".mcp.json"
Assert-Equal "{}" ([IO.File]::ReadAllText($got)) "reception de .mcp.json neuf : rien ajoute"

$script:HomeDir, $script:McpPerPc = $stripSaved
Remove-Item -LiteralPath (Join-Path $script:Sandbox "strip") -Recurse -Force
