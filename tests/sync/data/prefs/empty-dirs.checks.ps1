. (Join-Path (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "fakes") "fake-drive.ps1")
Use-Pc "VIDEA"
Save-Registry @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" })
Set-PcFile ".claude/skills/outil/SKILL.md" "s"
Set-PcFile ".claude/skills/outil/refs/a.md" "a"
Set-PcFile ".claude/skills/autre/SKILL.md" "b"
$r = Invoke-DriveSync
Assert-True $r.Ok ("skills envoyes " + $r.Error)

Use-Pc "VIDEB"
Save-Registry @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" })
$r = Invoke-DriveSync
Assert-Equal "s" (Get-PcText ".claude/skills/outil/SKILL.md") "skill recu"

Use-Pc "VIDEA"
Remove-Item -LiteralPath (Join-Path $script:HomeDir ".claude/skills/outil") -Recurse -Force
$r = Invoke-DriveSync
Assert-Equal 2 $r.Deleted "skill retire ici, retire du Drive"

Use-Pc "VIDEB"
$r = Invoke-DriveSync
Assert-Equal 2 $r.Deleted ("suppression recue " + $r.Error)
Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:HomeDir ".claude/skills/outil"))) "dossier vide du skill retire"
Assert-True (Test-Path -LiteralPath (Join-Path $script:HomeDir ".claude/skills/autre/SKILL.md")) "autre skill garde"

Set-PcFile ".claude/agents/seul.md" "x"
Remove-SyncLocalFile ".claude/agents/seul.md"
Assert-True (Test-Path -LiteralPath (Join-Path $script:HomeDir ".claude/agents")) "dossier du compte garde meme vide"
Set-PcFile ".claude/skills/plein/a.md" "a"
Set-PcFile ".claude/skills/plein/b.md" "b"
Remove-SyncLocalFile ".claude/skills/plein/a.md"
Assert-True (Test-Path -LiteralPath (Join-Path $script:HomeDir ".claude/skills/plein/b.md")) "dossier non vide garde"
Remove-SyncLocalFile ".claude/skills/absent/x.md"
Assert-True (Test-Path -LiteralPath (Join-Path $script:HomeDir ".claude/skills")) "fichier deja absent : rien d'autre retire"
Restore-FakeDrive
. (Join-Path $bin "drive/core/claude-drive-creds.ps1")
