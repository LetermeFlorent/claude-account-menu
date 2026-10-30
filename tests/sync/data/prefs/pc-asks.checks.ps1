. (Join-Path $bin "menu/manage/claude-menu-prefs.ps1")
. (Join-Path $bin "cli/claude-cli.ps1")
. (Join-Path (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "fakes") "fake-drive.ps1")

function Set-AskConfig {
  param([string]$Project)
  $p = ConvertTo-JsonString (ConvertTo-ProjectPath "Documents/p")
  Set-PcFile ".claude.json" ("{`"mcpServers`": {}, `"projects`": {" + $p + ": {`"mcpServers`": {" + $Project + "}}}}")
}

function Get-AskProjectNames {
  $m = Read-ProjectMcp (Get-PcText ".claude.json")
  return (@($m.Keys | Where-Object { $_.StartsWith("Documents/p|") } | ForEach-Object { (Split-McpKey $_).Name }) | Sort-Object) -join ","
}

function Get-AskPcData {
  param([string]$Pc)
  return ConvertFrom-PcData (ConvertFrom-JsonText (Get-FakePcText ($Pc + ".json"))) $false
}

function Invoke-AskSync {
  param([string]$Pc, [string]$Name)
  Use-Pc $Pc
  $r = Invoke-DriveSync
  Assert-True ($r.Ok -and $r.Failed -eq 0) ($Name + " " + $r.Error)
}

function Get-AskLine {
  param([string]$Pc, [string]$Id)
  Use-Pc "PA"
  return @(Resolve-PrefsItems (Get-PcPrefsLines (Read-SyncChoice) (Read-SyncCatalog) "PA" $Pc) @($Id))[0]
}

function Set-AskCheck {
  param([string]$Pc, [string]$Id, [bool]$On)
  $askTestItem = Get-AskLine $Pc $Id
  $askTestCat = Read-SyncCatalog
  $askTestPc = $Pc
  $askTestOn = $On
  $null = Update-SyncChoice { param($c) Set-PcPrefsCheck @{ Choice = $c; Catalog = $askTestCat; Me = "PA"; Pc = $askTestPc; Item = $askTestItem; On = $askTestOn } }
}

$oneAcc = @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" })
foreach ($pc in @("PA", "PB")) {
  Use-Pc $pc
  Save-Registry $oneAcc
  $null = New-Item -ItemType Directory -Path (Join-Path $script:HomeDir "Documents/p") -Force
}
Use-Pc "PA"
Set-PcFile ".claude/skills/outil/SKILL.md" "outil"
Set-PcFile ".claude/skills/dessin/SKILL.md" "dessin"
Set-AskConfig '"loc": {"command": "a"}'
Invoke-AskSync "PA" "premier PC"
Use-Pc "PB"
Set-AskConfig ""
Invoke-AskSync "PB" "second PC"
Assert-Equal "loc" (Get-AskProjectNames) "MCP du premier PC recu"
Invoke-AskSync "PA" "premier PC voit le second"
Assert-Equal $script:OsName (Get-AskPcData "PB").Os "systeme publie avec le fichier du PC"
Assert-Equal "PA PB" ((Get-PrefsPcs (Read-SyncCatalog) "PA") -join " ") "ce PC en premier, puis les autres"

$l = Get-AskLine "PB" "skill:outil"
Assert-Equal "True False" ("" + $l.On + " " + $l.Wait) "skill d'un autre PC coche par defaut"
Set-AskCheck "PB" "skill:outil" $false
Set-AskCheck "PB" "mcp:Documents/p|loc" $false
$l = Get-AskLine "PB" "skill:outil"
Assert-Equal "False True" ("" + $l.On + " " + $l.Wait) "case decochee pour l'autre PC : en attente"
$askAt = (Read-SyncChoice).Asks["PB"].skills["outil"].At

Invoke-AskSync "PA" "demande envoyee"
Assert-Equal $askAt (Get-AskPcData "PA").Asks["PB"].skills["outil"].At "demande publiee"
Invoke-AskSync "PB" "demande recue"
Assert-True (-not (Test-SkillChecked (Read-SyncChoice) "outil")) "demande appliquee sur l'autre PC"
Assert-Equal $askAt (Read-SyncChoice).Stamps.skills["outil"] "date de la demande gardee"
Assert-Equal "" (Get-AskProjectNames) "MCP decoche par la demande : retire de la config"
$pb = Get-AskPcData "PB"
Assert-True ($pb.Took["PA"] -ge $askAt -and $pb.Choice.skills["outil"] -eq $false) "prise en compte et choix publies"

Invoke-AskSync "PA" "demande prise en compte"
Assert-True (-not (Read-SyncChoice).Asks.ContainsKey("PB")) "demande prise en compte : retiree"
$l = Get-AskLine "PB" "skill:outil"
Assert-Equal "False False" ("" + $l.On + " " + $l.Wait) "case relue depuis le choix de l'autre PC"

Set-AskCheck "PB" "skill:outil" $true
Start-Sleep -Milliseconds 5
Use-Pc "PB"
$null = Update-SyncChoice { param($c) Set-PrefsState $c (New-PrefsItem @{ Kind = "skills"; Key = "outil"; Label = "outil"; Tag = ""; On = $false; Erasing = $false }) $false }
Invoke-AskSync "PA" "demande plus ancienne envoyee"
Invoke-AskSync "PB" "choix local plus recent"
Assert-True (-not (Test-SkillChecked (Read-SyncChoice) "outil")) "choix local plus recent garde"
Invoke-AskSync "PA" "demande ignoree"
Assert-True (-not (Read-SyncChoice).Asks.ContainsKey("PB")) "demande ignoree : retiree quand meme"

$old = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() - $script:AskKeepMs - 1000
$null = Update-SyncChoice { param($c) Add-PcAsk @{ Choice = $c; Pc = "PARTI"; Kind = "skills"; Name = "outil"; On = $true; After = 0 }; $c.Asks["PB"] = New-AskMaps; $c.Asks["PB"].skills["dessin"] = @{ On = $false; At = [long]$old } }
Invoke-AskSync "PA" "demandes perimees"
Assert-Equal 0 (Read-SyncChoice).Asks.Count "demandes vers un PC parti ou trop vieilles retirees"

$null = Send-FakePresence "VIEUX.json" ([Text.Encoding]::UTF8.GetBytes('{"mcp": {}, "erased": {}}')) @{ fmt = ("" + $script:SyncFormat) }
Invoke-AskSync "PA" "ancien clm present"
$cat = Read-SyncCatalog
Assert-True (-not (Test-PcReachable $cat "VIEUX")) "ancien clm : pas reglable d'ici"
Assert-Equal (Get-ClmText "sync.prefs.pc.old") (Get-PcPrefsSub $cat "VIEUX") "ancien clm : explication"

$script:Fake.Clear()
$script:FakePresence.Clear()
Restore-FakeDrive
