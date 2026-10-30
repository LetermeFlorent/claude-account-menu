. (Join-Path (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "fakes") "fake-drive.ps1")
Use-Pc "PCR"
Save-Registry @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" })
$null = Invoke-DriveSync

Set-PcFile ".claude/pareil.md" "meme"
Add-FakeSealed ".claude/pareil.md" "pareil" "meme"
Set-PcFile ".claude/nouveau.md" "neuf"
$script:SeenBase = $false
$script:OnSend = { param($Name) $script:SeenBase = (Read-DriveState).Files.ContainsKey(".claude/pareil.md") }
$r = Invoke-DriveSync
Assert-True $script:SeenBase "base enregistree apres les adoptions, avant le premier envoi"
Assert-Equal 1 $r.Up "adoption puis envoi"

$keptSaveEvery = $script:DriveSaveEveryMs
$script:DriveSaveEveryMs = 0
Set-PcFile ".claude/suite/a.md" "a"
Set-PcFile ".claude/suite/b.md" "b"
$script:SeenBase = $false
$script:OnSend = { param($Name) if ($Name -eq ".claude/suite/b.md") { $script:SeenBase = (Read-DriveState).Files.ContainsKey(".claude/suite/a.md") } }
$null = Invoke-DriveSync
Assert-True $script:SeenBase "base enregistree pendant la synchro, envoi par envoi"
$script:DriveSaveEveryMs = $keptSaveEvery
$script:OnSend = $null
Restore-FakeDrive
. (Join-Path $bin "drive/core/claude-drive-creds.ps1")
