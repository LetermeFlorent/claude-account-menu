$text = "{`n  `"numStartups`": 3,`n  `"mcpServers`": {`n    `"b`": { `"command`": `"npx`", `"args`": [`"-y`", `"a b`"] },`n    `"a`": {`"url`": `"http://x`"}`n  },`n  `"tips`": {}`n}`n"
$map = Read-McpMap $text
Assert-Equal "a,b" ((@($map.Keys) | Sort-Object) -join ",") "MCP lus par nom"
Assert-Equal '{"command":"npx","args":["-y","a b"]}' $map["b"] "definition compacte, espaces des chaines gardes"
Assert-Equal 0 (Read-McpMap '{"tips": 1}').Count "sans mcpServers : aucun MCP"
Assert-Equal 0 (Read-McpMap '{"mcpServers": null}').Count "mcpServers vide : aucun MCP"
Assert-Null (Read-McpMap '[1]') "texte qui n'est pas un objet : illisible"
Assert-Null (Read-McpMap '{"mcpServers": {') "JSON tronque : illisible"

$map.Remove("b")
$map["c"] = '{"command":"uvx"}'
$new = Set-McpMap $text $map
Assert-True ($new.StartsWith("{`n  `"numStartups`": 3,")) "reste du fichier garde avant"
Assert-True ($new.Contains("`"tips`": {}")) "reste du fichier garde apres"
Assert-Equal "a,c" ((@((Read-McpMap $new).Keys) | Sort-Object) -join ",") "MCP remplaces"
Assert-True ((Test-McpMapEqual (Read-McpMap $new) $map)) "relecture identique"
$added = Set-McpMap '{"tips": 1}' $map
Assert-True (Test-McpMapEqual (Read-McpMap $added) $map) "mcpServers ajoute s'il manque"
Assert-Equal '{"mcpServers": {}}' (Set-McpMap '{"mcpServers": {"x": {}}}' (New-PathMap)) "tous les MCP retires : objet vide"
Assert-Null (Set-McpMap 'pas du json' $map) "fichier illisible : rien ecrit"

$other = New-PathMap
$other["a"] = '{"url":"http://x"}'
$other["c"] = '{"command":"uvx" }'
Assert-True (-not (Test-McpMapEqual $other $map)) "definitions differentes"
Assert-True (Test-McpMapEqual $null $null) "deux absents : egaux"
Assert-True (-not (Test-McpMapEqual $map $null)) "un absent : differents"

$path = Join-Path $script:Sandbox "mcp-json/.claude.json"
$null = New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force
Assert-Null (Read-McpFile $path) "fichier absent : rien lu"
Write-McpFile $path $map
Assert-True (Test-McpMapEqual (Read-McpFile $path) $map) "fichier absent : cree avec les MCP"
[IO.File]::WriteAllText($path, '{"mcpServers": {"a": 1')
$err = ""
try { Write-McpFile $path $map } catch { $err = $_.Exception.Message }
Assert-True ($err -ne "") "fichier illisible : ecriture refusee"
Assert-Equal '{"mcpServers": {"a": 1' ([IO.File]::ReadAllText($path)) "fichier illisible : garde tel quel"
[IO.File]::WriteAllText($path, '{"x": 1}')
$bad = New-PathMap
$bad["z"] = '{"a": '
$err = ""
try { Write-McpFile $path $bad } catch { $err = $_.Exception.Message }
Assert-True ($err -ne "") "definition cassee : ecriture refusee"
Assert-Equal '{"x": 1}' ([IO.File]::ReadAllText($path)) "definition cassee : fichier garde"
Remove-Item -LiteralPath (Split-Path -Parent $path) -Recurse -Force
