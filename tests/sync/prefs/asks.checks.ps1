. (Join-Path $bin "claude-menu-prefs.ps1")

$asksSaved = @($script:SyncChoicePath, $script:SyncChoiceLockPath, $script:SyncChoiceWaitMs)
$script:SyncChoicePath = Join-Path $script:Sandbox "asks-choice.json"
$script:SyncChoiceLockPath = Join-Path $script:Sandbox "asks-choice.lock"
$script:SyncChoiceWaitMs = 0

$now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$c = New-SyncChoice
Add-PcAsk $c "bureau" "skills" "outil" $false 0
$a = $c.Asks["bureau"].skills["outil"]
Assert-True ((-not $a.On) -and $a.At -ge $now) "demande datee de maintenant"
$later = $now + 100000
Add-PcAsk $c "bureau" "skills" "outil" $true $later
Assert-Equal ($later + 1) $c.Asks["bureau"].skills["outil"].At "demande toujours apres la derniere prise en compte"
Add-PcAsk $c "bureau" "skills" "outil" $false 0
Assert-Equal ($later + 2) $c.Asks["bureau"].skills["outil"].At "nouvelle demande toujours plus recente"
Remove-PcAsk $c "bureau" "skills" "outil"
Assert-True (-not $c.Asks.ContainsKey("bureau")) "PC sans demande retire"
Remove-PcAsk $c "absent" "skills" "outil"

$null = Update-SyncChoice { param($x) Add-PcAsk $x "bureau" "mcp" "Documents/p|loc" $true 0; Set-ChoiceStamp $x "skills" "outil" }
$back = Read-SyncChoice
Assert-True $back.Asks["bureau"].mcp["Documents/p|loc"].On "demande relue"
Assert-True ($back.Stamps.skills["outil"] -ge $now) "date du choix relue"
$null = Update-SyncChoice { param($x) Remove-PcAsk $x "bureau" "mcp" "Documents/p|loc"; $x.Stamps.skills.Clear() }
$text = [IO.File]::ReadAllText($script:SyncChoicePath)
Assert-True (-not $text.Contains('"asks"') -and -not $text.Contains('"stamps"')) "sans demande ni date : rien d'ecrit"

$raw = ConvertFrom-JsonText '{"bureau": {"skills": {"outil": {"on": false, "at": 5}, "../x": {"on": true, "at": 5}, "texte": {"on": 1, "at": 5}, "zero": {"on": true, "at": 0}}}, "a/b": {"skills": {"outil": {"on": true, "at": 5}}}, "vide": {"skills": {}}, "liste": []}'
$asks = ConvertFrom-AsksData $raw
Assert-Equal "bureau" (@($asks.Keys) -join ",") "demandes illisibles ignorees"
Assert-Equal "outil" (@($asks["bureau"].skills.Keys) -join ",") "seule la demande valide reste"
Assert-Equal 0 (ConvertFrom-AsksData "texte").Count "demandes qui ne sont pas un objet ignorees"
Assert-Equal "bureau" (@((ConvertFrom-TookData (ConvertFrom-JsonText '{"bureau": 4, "x": -1, "y": "z", "a/b": 3}')).Keys) -join ",") "prises en compte illisibles ignorees"

$pcData = New-PcContent
$old = ConvertTo-JsonText (ConvertTo-PcData $pcData)
Assert-True (-not $old.Contains('"os"') -and -not $old.Contains('"asks"')) "sans systeme : fichier de PC inchange"
$pcData.Os = $script:OsName
$pcData.Choice.skills["outil"] = $false
$pcData.Asks["bureau"] = New-AskMaps
$pcData.Asks["bureau"].skills["dessin"] = @{ On = $true; At = [long]7 }
$pcData.Took["bureau"] = [long]9
$back = ConvertFrom-PcData (ConvertFrom-JsonText (ConvertTo-JsonText (ConvertTo-PcData $pcData))) $false
$got = $back.Os + " " + $back.Choice.skills["outil"] + " " + $back.Asks["bureau"].skills["dessin"].On + " " + $back.Asks["bureau"].skills["dessin"].At + " " + $back.Took["bureau"]
Assert-Equal ($script:OsName + " False True 7 9") $got "fichier de PC relu"
$noOs = ConvertFrom-PcData (ConvertFrom-JsonText '{"mcp": {}, "erased": {}, "choice": {"skills": {"outil": false}}}') $false
Assert-True (-not $noOs.Os -and $noOs.Choice.skills.Count -eq 0) "ancien clm : reglages ignores"

$pcs = New-PathMap
foreach ($n in @("moi", "autre", "cible")) { $pcs[$n] = New-PcContent }
$pcs["cible"].Os = $script:OsName
$pcs["cible"].Took["autre"] = [long]10
$pcs["cible"].Choice.skills["vieux"] = $false
$pcs["autre"].Asks["cible"] = New-AskMaps
$pcs["autre"].Asks["cible"].skills["vieux"] = @{ On = $true; At = [long]10 }
$pcs["autre"].Asks["cible"].skills["neuf"] = @{ On = $false; At = [long]11 }
$mine = New-SyncChoice
$mine.Asks["cible"] = New-AskMaps
$mine.Asks["cible"].skills["neuf"] = @{ On = $true; At = [long]12 }
$pend = Get-PcPending $pcs $mine "moi" "cible"
Assert-Equal "neuf" (@($pend.Others.skills.Keys) -join ",") "demande deja prise en compte : plus en attente"
Assert-True $pend.Mine.skills["neuf"].On "ma demande en attente"

$cat = @{ Pcs = $pcs; Skills = [string[]]@("neuf", "vieux", "seul"); PerPc = $false }
$lines = Get-PcPrefsLines $mine $cat "moi" "cible"
$shown = @($lines | Where-Object { -not $_.Head -and -not $_.All } | ForEach-Object { $_.Key + "=" + $_.On + "/" + $_.Base + "/" + $_.Wait })
Assert-Equal "neuf=True/False/True seul=True/True/False vieux=False/False/False" ($shown -join " ") "cases d'un autre PC : son choix, puis les demandes, la plus recente gagne"
Assert-True ($lines[1].All -and $lines[1].Mixed -and $lines[1].Tag -eq "coches : 2 sur 3") "cases d'un autre PC : une case pour tous les skills"
Assert-Equal 0 (Get-PcPrefsLines $mine $cat "moi" "autre").Count "PC sans clm a jour : rien a regler"
Assert-Equal 0 (Get-PcPrefsLines $mine $cat "moi" "inconnu").Count "PC inconnu : rien a regler"

$neuf = @($lines | Where-Object { $_.Key -eq "neuf" })[0]
Set-PcPrefsCheck $mine $cat "moi" "cible" $neuf $false
Assert-True (-not $mine.Asks.ContainsKey("cible")) "case remise a sa valeur : ma demande retiree"
$seul = @($lines | Where-Object { $_.Key -eq "seul" })[0]
Set-PcPrefsCheck $mine $cat "moi" "cible" $seul $false
Assert-True (-not $mine.Asks["cible"].skills["seul"].On) "case decochee pour un autre PC : demande ajoutee"

$script:SyncChoicePath, $script:SyncChoiceLockPath, $script:SyncChoiceWaitMs = $asksSaved
