$projSaved = $script:HomeDir
$script:HomeDir = "C:\Users\test"
$caseRel = "Documents/p"
if ($script:OsName -eq "Linux") { $caseRel = "" }
Assert-Equal "Documents/p" (ConvertTo-ProjectRel "C:/Users/test/Documents/p") "projet sous le dossier perso"
Assert-Equal "Documents/p" (ConvertTo-ProjectRel "C:\Users\test\Documents\p\") "projet avec barres inverses"
Assert-Equal "" (ConvertTo-ProjectRel "C:/Users/testeur/x") "dossier voisin du dossier perso ignore"
Assert-Equal "" (ConvertTo-ProjectRel "C:/Users/test") "dossier perso lui-meme ignore"
Assert-Equal "" (ConvertTo-ProjectRel "C:/Users/test/a/../b") "chemin avec .. ignore"
Assert-Equal $caseRel (ConvertTo-ProjectRel "c:/users/TEST/Documents/p") "casse du chemin selon le systeme"
Assert-True ((Test-McpKey "|a") -and (Test-McpKey "Documents/p|a")) "cles valides"
Assert-True (-not (Test-McpKey "a") -and -not (Test-McpKey "../x|a") -and -not (Test-McpKey "p|")) "cles invalides refusees"

$text = @'
{"tips": 1, "projects": {
  "C:/Users/test/Documents/p": {"x": 1, "mcpServers": {"a": {"command": "a"}, "b": {}}},
  "C:\\Users\\test\\Documents\\q": {"mcpServers": {"q": {}}},
  "D:/ailleurs": {"mcpServers": {"c": {}}},
  "C:/Users/test/vide": {"x": 2}
}}
'@
$m = Read-ProjectMcp $text
Assert-Equal "Documents/p|a,Documents/p|b,Documents/q|q" ((@($m.Keys) | Sort-Object) -join ",") "lecture : MCP des projets du dossier perso"
Assert-Equal '{"command":"a"}' $m["Documents/p|a"] "lecture : definition compacte"
Assert-Equal 0 (Read-ProjectMcp '{"tips": 1}').Count "lecture sans projets : vide"
Assert-Null (Read-ProjectMcp '{"projects": {') "lecture illisible : rien"

$want = New-PathMap
$want["Documents/p|a"] = '{"command":"a2"}'
$want["Documents/q|q"] = '{}'
$want["Documents/neuf|n"] = '{}'
$out = Set-ProjectMcp $text $want
$null = ConvertFrom-JsonText $out
Assert-Equal "Documents/neuf|n,Documents/p|a,Documents/q|q" ((@((Read-ProjectMcp $out).Keys) | Sort-Object) -join ",") "ecriture : projets mis a jour et ajoutes"
Assert-Equal '{"command":"a2"}' (Read-ProjectMcp $out)["Documents/p|a"] "ecriture : definition changee"
Assert-True ($out.Contains('"x": 1') -and $out.Contains('"x": 2') -and $out.Contains('"c": {}')) "ecriture : reglages et projets ailleurs gardes"
Assert-True ($out.Contains('"C:/Users/test/Documents/neuf"')) "ecriture : nouveau projet en chemin complet"
Assert-True ($out.Contains('"C:\\Users\\test\\Documents\\q"')) "ecriture : nom du projet existant garde"
Assert-Equal $text (Set-ProjectMcp $text (Read-ProjectMcp $text)) "ecriture identique : texte inchange"
$none = Set-ProjectMcp $text (New-PathMap)
Assert-Equal 0 (Read-ProjectMcp $none).Count "ecriture vide : MCP des projets retires"
Assert-True ($none.Contains('"c": {}')) "ecriture vide : projet ailleurs garde"
Assert-Equal '{"tips": 1}' (Set-ProjectMcp '{"tips": 1}' (New-PathMap)) "ecriture vide sans projets : texte inchange"
$added = Set-ProjectMcp '{"tips": 1}' $want
Assert-Equal 3 (Read-ProjectMcp $added).Count "ecriture sans projets : projets ajoutes"
Assert-Null (Set-ProjectMcp '{"projects": {' $want) "ecriture illisible : rien"
if ($script:OsName -ne "Linux") {
  $cased = Set-ProjectMcp '{"projects": {"c:/users/TEST/documents/P": {"mcpServers": {}}}}' $want
  Assert-True (-not $cased.Contains("Documents/p")) "ecriture : projet existant retrouve sans la casse"
  $twice = Read-ProjectMcp (Set-ProjectMcp '{"projects": {"C:/Users/test/Documents/p": {"mcpServers": {"a": {}}}, "c:/users/test/documents/p": {"mcpServers": {"b": {}}}}}' $want)
  Assert-True ($twice["Documents/p|a"] -eq '{"command":"a2"}' -and $twice["documents/p|a"] -eq '{"command":"a2"}' -and -not $twice.ContainsKey("documents/p|b")) "ecriture : meme projet ecrit sous ses deux casses"
}

$caseMap = New-ProjectCaseMap
Add-ProjectCase $caseMap @("Documents/P|x", "|h")
$loose = New-PathMap
$loose["documents/p|y"] = "1"
$loose["|h"] = "2"
$loose["Autre|z"] = "3"
$caseKey = "Documents/P|y"
if ($script:OsName -eq "Linux") { $caseKey = "documents/p|y" }
$conv = Convert-McpMapCase $caseMap $loose
Assert-True ($conv[$caseKey] -eq "1" -and $conv["|h"] -eq "2" -and $conv["Autre|z"] -eq "3" -and $conv.Count -eq 3) "casse des projets alignee sur le catalogue selon le systeme"
Assert-Null (Convert-McpMapCase $caseMap $null) "casse : fichier illisible reste illisible"

$stripped = Remove-ProjectMcp $text
$null = ConvertFrom-JsonText $stripped
Assert-Equal 0 (Read-ProjectMcp $stripped).Count "retrait : MCP des projets du dossier perso retires"
Assert-True ($stripped.Contains('"c": {}') -and $stripped.Contains('"x": 1')) "retrait : projet ailleurs et reglages gardes"
Assert-Equal '{"tips": 1}' (Remove-ProjectMcp '{"tips": 1}') "retrait sans projets : texte inchange"

$file = Join-Path $script:Sandbox "projets.json"
Write-ProjectMcpFile $file $want
Assert-Equal 3 (Read-ProjectMcp ([IO.File]::ReadAllText($file))).Count "fichier absent : cree avec les projets"
[IO.File]::WriteAllText($file, "{casse")
$threw = $false
try { Write-ProjectMcpFile $file $want } catch { $threw = $true }
Assert-True ($threw -and [IO.File]::ReadAllText($file) -eq "{casse") "fichier illisible : erreur et fichier garde"
Remove-Item -LiteralPath $file -Force
$script:HomeDir = $projSaved
