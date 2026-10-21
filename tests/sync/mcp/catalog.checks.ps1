$catalogSaved = $script:SyncCatalogPath
$script:SyncCatalogPath = Join-Path $script:Sandbox "catalog.json"
$long = '{"a": "' + ("x" * $script:McpDefMax) + '"}'
$raw = @"
{"md5": "m1",
 "mcp": {
  "|ok": {"at": 5, "os": "Windows", "def": "{\"command\":\"x\"}"},
  "Documents/p|outil": {"at": 5, "os": "Linux", "def": "{}"},
  "|gone": {"at": 9, "deleted": true},
  "|zero": {"at": 0, "os": "Windows", "def": "{}"},
  "|texte": {"at": "5", "os": "Windows", "def": "{}"},
  "|os": {"at": 5, "os": "Win 11", "def": "{}"},
  "sans-projet": {"at": 5, "os": "Linux", "def": "{}"},
  "../haut|a": {"at": 5, "os": "Linux", "def": "{}"},
  "/abs|a": {"at": 5, "os": "Linux", "def": "{}"},
  "|tableau": {"at": 5, "os": "Linux", "def": "[1]"},
  "|casse": {"at": 5, "os": "Linux", "def": "{\"a\": "},
  "|long": {"at": 5, "os": "Linux", "def": $(ConvertTo-JsonString $long)},
  "|gu\"il": {"at": 5, "os": "Linux", "def": "{}"}
 },
 "erased": {"s": 10, "a/b": 5, "neg": -1, "t": "x"}}
"@
$c = ConvertFrom-PcData (ConvertFrom-JsonText $raw) $false
$keys = [string[]]@($c.Mcp.Keys)
[Array]::Sort($keys, [StringComparer]::Ordinal)
Assert-Equal "Documents/p|outil,|gone,|ok" ($keys -join ",") "fichier d'un autre PC : seules les entrees valides gardees"
Assert-Equal "m1" $c.Md5 "fichier d'un autre PC : empreinte lue"
Assert-True $c.Mcp["|gone"].Deleted "entree effacee lue"
Assert-Equal '{"command":"x"}' $c.Mcp["|ok"].Def "definition lue"
Assert-Equal "s" (@($c.Erased.Keys) -join ",") "skills effaces : noms et dates valides seulement"
Assert-Equal 0 (ConvertFrom-PcData "texte" $false).Mcp.Count "contenu qui n'est pas un objet : vide"
Assert-Equal 0 (ConvertFrom-PcData (ConvertFrom-JsonText '{"mcp": [1], "erased": 3}') $false).Mcp.Count "parties mal formees : ignorees"
Assert-Equal "Documents/p|a|b" ((Split-McpKey "Documents/p|a|b").Project + "|" + (Split-McpKey "Documents/p|a|b").Name) "cle coupee au premier separateur"

function New-TestEntry {
  param([long]$At, [string]$Def, [switch]$Deleted)
  return @{ At = $At; Deleted = [bool]$Deleted; Os = "Linux"; Def = $Def }
}
$pcs = New-PathMap
$pcs["A"] = New-PcContent
$pcs["B"] = New-PcContent
$pcs["A"].Mcp["|x"] = New-TestEntry 5 "a"
$pcs["B"].Mcp["|x"] = New-TestEntry 7 "b"
$pcs["A"].Mcp["|y"] = New-TestEntry 5 "" -Deleted
$pcs["B"].Mcp["|y"] = New-TestEntry 5 "b"
$pcs["A"].Mcp["|z"] = New-TestEntry 4 "a"
$pcs["B"].Mcp["|z"] = New-TestEntry 4 "b"
$pcs["A"].Mcp["|w"] = New-TestEntry 2 "a"
$cat = Get-McpCatalog $pcs
Assert-Equal "b" $cat["|x"].Def "catalogue : entree la plus recente gagne"
Assert-True (-not $cat.ContainsKey("|y")) "catalogue : effacement a egalite gagne"
Assert-Equal "b" $cat["|z"].Def "catalogue : egalite departagee par le nom du PC"
Assert-Equal "a" $cat["|w"].Def "catalogue : entree d'un seul PC"
Assert-True (Get-McpCatalog $pcs -WithDeleted)["|y"].Deleted "catalogue complet : effacements gardes"
$pcs["B"].Erased["s"] = [long]8
$pcs["A"].Erased["s"] = [long]3
$pcs["A"].Erased["t"] = [long]1
$erased = Get-ErasedSkills $pcs
Assert-Equal "8|1" ("" + $erased["s"] + "|" + $erased["t"]) "skills effaces : date la plus recente par nom"

$saved = New-SyncCatalog
$saved.PerPc = $true
$saved.Waiting = [string[]]@("vieux")
$saved.Skills = [string[]]@("s1", "s2")
$saved.Globals = [string[]]@("g1")
$saved.Parked["g2"] = '{"command":"p"}'
$saved.Pcs = $pcs
$applied = New-PathMap
$applied["|d"] = '{"u":1}'
$saved.Applied[".claude.json"] = $applied
Save-SyncCatalog $saved
$back = Read-SyncCatalog
Assert-True $back.PerPc "catalogue relu : mode par PC"
Assert-Equal "vieux" ($back.Waiting -join ",") "catalogue relu : PC pas a jour"
Assert-Equal "s1,s2" ($back.Skills -join ",") "catalogue relu : skills du Drive"
Assert-Equal "g1" ($back.Globals -join ",") "catalogue relu : globaux vus"
Assert-Equal '{"command":"p"}' $back.Parked["g2"] "catalogue relu : globaux mis de cote"
Assert-Equal "b" (Get-McpCatalog $back.Pcs)["|x"].Def "catalogue relu : fichiers des PC"
Assert-Equal '{"u":1}' $back.Applied[".claude.json"]["|d"] "catalogue relu : base appliquee"
Assert-Equal 8 $back.Pcs["B"].Erased["s"] "catalogue relu : skills effaces"
Assert-Null (New-SyncCatalog).Globals "catalogue neuf : globaux jamais vus"
[IO.File]::WriteAllText($script:SyncCatalogPath, "{casse")
Assert-Equal 0 (Read-SyncCatalog).Pcs.Count "catalogue illisible : vide"
Remove-Item -LiteralPath $script:SyncCatalogPath -Force
$script:SyncCatalogPath = $catalogSaved
