Assert-Equal "outil" (Get-SkillOfPath ".claude/skills/outil/refs/a.md") "skill d'un chemin"
Assert-Equal "" (Get-SkillOfPath ".claude/skills/seul.md") "fichier a la racine des skills : aucun skill"
Assert-Equal "" (Get-SkillOfPath ".claude-c2/skills/outil/a.md") "skills d'un autre compte : ignores"
Assert-True (-not ((Test-SkillName ".trash") -or (Test-SkillName ".") -or (Test-SkillName ".."))) "dossier masque : jamais un skill"
Assert-True (Test-SkillName "outil.v2") "point dans le nom : skill"
$hiddenListing = New-PathMap
$hiddenListing[".claude/skills/.trash/vieux/SKILL.md"] = @{ Id = "t" }
$hiddenListing[".claude/skills/outil/SKILL.md"] = @{ Id = "o" }
Assert-Equal "outil" ((Get-DriveSkillNames $hiddenListing) -join ",") "skills du Drive : dossier masque ignore"
Assert-Equal 'a`[1`]`*`?``' (ConvertTo-WildcardLiteral 'a[1]*?`') "nom de skill protege dans le motif"
$choice = New-SyncChoice
$choice.skills["a[1]"] = $false
$choice.skills["vu"] = $true
$choice.skills["deux"] = $false
$choice.Erase.skills.Add("vieux")
$rx = Get-ExcludeRegex (Get-SkillExcludes $choice)
Assert-True ($rx.IsMatch(".claude/skills/a[1]/x.md")) "skill decoche exclu"
Assert-True (-not $rx.IsMatch(".claude/skills/a1/x.md")) "crochets pris a la lettre"
Assert-True ($rx.IsMatch(".claude/skills/deux/x.md")) "plusieurs skills decoches exclus"
Assert-True ($rx.IsMatch(".claude/skills/vieux/SKILL.md")) "skill a effacer exclu"
Assert-True (-not $rx.IsMatch(".claude/skills/vu/SKILL.md")) "skill coche garde"
$offCat = @{ Pcs = (New-PathMap) }
$offChoice = New-SyncChoice
$offChoice.skills["x"] = $false
Assert-True (Test-SkillOffEverywhere $offChoice $offCat "MOI" "x") "seul PC : decoche ici, decoche partout"
$offCat.Pcs["AUTRE"] = New-PcContent
$offCat.Pcs["AUTRE"].Choice.skills["x"] = $false
Assert-True (-not (Test-SkillOffEverywhere $offChoice $offCat "MOI" "x")) "PC dont clm n'est pas a jour : compte comme coche"
$offCat.Pcs["AUTRE"].Os = "Windows"
Assert-True (Test-SkillOffEverywhere $offChoice $offCat "MOI" "x") "decoche sur chaque PC : decoche partout"
Add-PcAsk @{ Choice = $offChoice; Pc = "AUTRE"; Kind = "skills"; Name = "x"; On = $true; After = 0 }
Assert-True (-not (Test-SkillOffEverywhere $offChoice $offCat "MOI" "x")) "demande de recocher en attente : pas decoche partout"
Remove-PcAsk $offChoice "AUTRE" "skills" "x"
$offCat.Pcs["AUTRE"].Choice.skills.Remove("x")
Assert-True (-not (Test-SkillOffEverywhere $offChoice $offCat "MOI" "x")) "coche sur un autre PC : pas decoche partout"

. (Join-Path (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "fakes") "fake-drive.ps1")
Use-Pc "SKA"
Save-Registry @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" })
Set-PcFile ".claude/skills/garde/SKILL.md" "g"
Set-PcFile ".claude/skills/off/SKILL.md" "o"
Set-PcFile ".claude/skills/.trash/vieux/SKILL.md" "t"
Assert-Equal "garde,off" (((Get-LocalSkillNames) | Sort-Object) -join ",") "skills de ce PC : dossier masque ignore"
$null = Measure-Entries @(".claude") @(Get-SaveExcludes @(Get-Accounts))
Assert-True ($script:Sizes.ContainsKey(".claude/skills/garde/SKILL.md") -and -not $script:Sizes.ContainsKey(".claude/skills/.trash/vieux/SKILL.md")) "taille de la sauvegarde : dossier masque des skills compte pour rien"
foreach ($i in 1..22) { Set-PcFile (".claude/skills/efface/f" + $i + ".md") "e" }
$r = Invoke-DriveSync
Assert-True $r.Ok ("skills envoyes " + $r.Error)
Assert-True (-not (Test-FakeFile ".claude/skills/.trash/vieux/SKILL.md")) "dossier masque des skills : jamais envoye"

Use-Pc "SKB"
Save-Registry @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" })
$r = Invoke-DriveSync
Assert-Equal "e" (Get-PcText ".claude/skills/efface/f22.md") "skills recus"
$null = Update-SyncChoice { param($c) Set-ChoiceCheck $c "skills" "off" $false $true; Set-ChoiceCheck $c "skills" "perso" $false $true }
Set-PcFile ".claude/skills/perso/SKILL.md" "p"
$r = Invoke-DriveSync
Assert-True $r.Ok ("skill decoche " + $r.Error)
Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:HomeDir ".claude/skills/off"))) "skill decoche present sur le Drive : retire ici"
Assert-True (Test-FakeFile ".claude/skills/off/SKILL.md") "skill decoche : garde sur le Drive"
Assert-Equal "p" (Get-FakeText ".claude/skills/perso/SKILL.md") "skill decoche absent du Drive : envoye d'abord"
Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:HomeDir ".claude/skills/perso"))) "skill decoche absent du Drive : retire ici une fois envoye"
Assert-Equal "efface,garde,off" ((Read-SyncCatalog).Skills -join ",") "liste des skills du Drive gardee"

Use-Pc "SKA"
Set-PcFile ".claude/skills/off/SKILL.md" "o2"
$null = Update-SyncChoice { param($c) Add-EraseRequest $c "skills" "efface" }
$r = Invoke-DriveSync
Assert-True $r.Ok ("effacement " + $r.Error)
Assert-Equal 0 @((Get-FakeRels) | Where-Object { $_.StartsWith(".claude/skills/efface/") }).Count "skill efface : retire du Drive"
Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:HomeDir ".claude/skills/efface"))) "skill efface : retire ici"
Assert-Equal 0 (Read-SyncChoice).Erase.skills.Count "effacement fait : demande retiree"
Assert-True ((Get-FakePcText "SKA.json").Contains('"efface"')) "skill efface annonce aux autres PC"
Assert-Equal "garde,off,perso" ((Read-SyncCatalog).Skills -join ",") "liste des skills sans le skill efface"
Assert-Equal "p" (Get-PcText ".claude/skills/perso/SKILL.md") "skill decoche sur un autre PC : recu ici"

Use-Pc "SKB"
$r = Invoke-DriveSync
Assert-True $r.Ok ("effacement recu malgre la limite de suppressions " + $r.Error)
Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:HomeDir ".claude/skills/efface"))) "skill efface ailleurs : retire ici"
Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:HomeDir ".claude/skills/off"))) "skill decoche : modification pas recue"

Use-Pc "SKA"
Set-PcFile ".claude/skills/garde/SKILL.md" "g2"
$null = Update-SyncChoice { param($c) Set-ChoiceCheck $c "skills" "garde" $false $true; Set-ChoiceCheck $c "skills" "perso" $false $true }
$r = Invoke-DriveSync
Assert-True $r.Ok ("decoche ici apres une modification " + $r.Error)
Assert-Equal "g2" (Get-FakeText ".claude/skills/garde/SKILL.md") "skill decoche modifie ici : modification envoyee avant le retrait"
Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:HomeDir ".claude/skills/garde"))) "skill decoche modifie ici : retire une fois envoye"
Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:HomeDir ".claude/skills/perso"))) "skill decoche partout : retire ici d'abord"
Assert-True (Test-FakeFile ".claude/skills/perso/SKILL.md") "skill decoche partout : reste sur le Drive tant qu'il est ici"
$r = Invoke-DriveSync
Assert-True $r.Ok ("decoche partout " + $r.Error)
Assert-Equal 0 @((Get-FakeRels) | Where-Object { $_.StartsWith(".claude/skills/perso/") }).Count "skill decoche partout : retire du Drive"
Assert-True (Test-FakeFile ".claude/skills/garde/SKILL.md") "skill coche sur un autre PC : garde sur le Drive"
Assert-True (-not (Read-SyncChoice).skills.ContainsKey("perso")) "skill parti du Drive : case oubliee ici"
Assert-True ((Read-SyncChoice).skills.ContainsKey("garde")) "skill encore sur le Drive : case gardee"

Use-Pc "SKB"
$r = Invoke-DriveSync
Assert-True $r.Ok ("skill decoche partout, autre PC " + $r.Error)
Assert-True (-not (Read-SyncChoice).skills.ContainsKey("perso")) "skill parti du Drive : case oubliee sur l'autre PC"
Assert-Equal "g2" (Get-PcText ".claude/skills/garde/SKILL.md") "skill coche ici : modification recue"

$target = Join-Path $script:Sandbox "cible-lien"
$null = New-Item -ItemType Directory -Path $target -Force
[IO.File]::WriteAllText((Join-Path $target "a.md"), "a")
$linkType = "SymbolicLink"
if ($script:OsName -eq "Windows") { $linkType = "Junction" }
$null = New-Item -ItemType $linkType -Path (Join-Path $script:HomeDir ".claude/skills/lien") -Target $target
Assert-True (-not (Remove-LocalSkill "lien")) "lien : jamais retire"
Assert-True (Test-Path -LiteralPath (Join-Path $target "a.md")) "lien : cible intacte"
Assert-True (-not (Remove-LocalSkill "..")) "nom de skill invalide : rien retire"
[IO.Directory]::Delete((Join-Path $script:HomeDir ".claude/skills/lien"))
Remove-Item -LiteralPath $target -Recurse -Force
Restore-FakeDrive
. (Join-Path $bin "drive/core/claude-drive-creds.ps1")
