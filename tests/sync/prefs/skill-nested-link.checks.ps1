. (Join-Path $PSScriptRoot "..\fake-drive.ps1")

Use-Pc "NL"
$nestTarget = Join-Path $script:Sandbox "cible-imbriquee"
$null = New-Item -ItemType Directory -Path (Join-Path $nestTarget "sous") -Force
[IO.File]::WriteAllText((Join-Path $nestTarget "a.md"), "a")
[IO.File]::WriteAllText((Join-Path $nestTarget "sous\b.md"), "b")
Set-PcFile ".claude/skills/outil/SKILL.md" "s"
Set-PcFile ".claude/skills/outil/dossier/c.md" "c"
$nestType = "SymbolicLink"
if ($script:OsName -eq "Windows") { $nestType = "Junction" }
$null = New-Item -ItemType $nestType -Path (Join-Path $script:HomeDir ".claude/skills/outil/dossier/lien") -Target $nestTarget
$null = New-Item -ItemType $nestType -Path (Join-Path $script:HomeDir ".claude/skills/outil/lien-dossier") -Target $nestTarget

Assert-True (Remove-LocalSkill "outil") "skill avec liens imbriques : retire"
Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:HomeDir ".claude/skills/outil"))) "skill avec liens imbriques : dossier disparu"
Assert-Equal "a" ([IO.File]::ReadAllText((Join-Path $nestTarget "a.md"))) "lien imbrique : contenu de la cible intact"
Assert-Equal "b" ([IO.File]::ReadAllText((Join-Path $nestTarget "sous\b.md"))) "lien imbrique : sous-dossier de la cible intact"
Remove-Item -LiteralPath $nestTarget -Recurse -Force
Restore-FakeDrive
