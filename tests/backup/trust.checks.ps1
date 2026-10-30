. (Join-Path $bin "menu/manage/claude-menu-archive.ps1")
. (Join-Path $bin "menu/manage/claude-menu-save.ps1")
. (Join-Path $bin "menu/manage/claude-menu-restore.ps1")
. (Join-Path $bin "cli/claude-cli.ps1")
$trHome = $script:HomeDir
$trRegistry = $script:RegistryPath
$trRoot = Join-Path $script:Sandbox "confiance"
$script:HomeDir = Join-Path $trRoot "maison"
$script:RegistryPath = Join-Path (Join-Path $trRoot "etat") "accounts.json"
$script:TrustDl = Join-Path $trRoot "dl"
$null = New-Item -ItemType Directory -Path $script:HomeDir, $script:TrustDl, (Split-Path -Parent $script:RegistryPath) -Force
function Get-DownloadsDir { return $script:TrustDl }
function Set-TrustText { param([string]$Rel, [string]$Text) $null = New-SandboxFile ("confiance/maison/" + $Rel) $Text }
Save-Registry @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" })
Set-TrustText ".claude/settings.json" '{"model": "opus", "hooks": {"SessionStart": [{"hooks": [{"type": "command", "command": "echo a"}]}]}}'
Set-TrustText ".claude.json" '{"mcpServers": {"a": {"command": "x"}}, "numStartups": 1}'

$trSaved = Save-Accounts
$trZip = @(Get-Backups)[0].FullName
Assert-True ($trSaved.StartsWith($trZip)) "archive de clm : listee"
Assert-True (Test-BackupTrusted $trZip) "archive de clm : reconnue"
if ($script:OsName -ne "Windows") {
  Assert-Equal "-rw-------" (Get-Item -LiteralPath $trZip).UnixMode "archive lisible par son seul proprietaire"
  Assert-Equal "-rw-------" (Get-Item -LiteralPath (Get-StatePath $script:BackupKeyName)).UnixMode "cle des archives lisible par son seul proprietaire"
}

$null = New-SandboxFile "confiance/autre/.claude/CLAUDE.md" "autre"
$trForeign = Join-Path $script:TrustDl ("claude-comptes-autre" + (Get-ArchiveExtension $script:TarFlavor))
& $script:Tar -a -c -f $trForeign -C (Join-Path $trRoot "autre") ".claude"
Assert-Equal 0 @(Get-Backups | Where-Object { $_.FullName -eq $trForeign }).Count "archive d'ailleurs : absente de la liste"
Assert-True (-not (Test-BackupTrusted $trForeign)) "archive d'ailleurs : pas reconnue"
Assert-Throws { Restore-Accounts $trForeign } (Get-ClmText "backup.restore.foreign") "archive d'ailleurs : restauration refusee sans chemin explicite"
$trWarn = @(Restore-Accounts $trForeign -AllowForeign 3>&1 | Where-Object { $_ -is [Management.Automation.WarningRecord] })
Assert-True ($trWarn.Count -ge 1) "archive d'ailleurs : restauree a la demande, avec un avertissement"
Assert-Equal "autre" ([IO.File]::ReadAllText((Join-Path $script:HomeDir ".claude/CLAUDE.md"))) "archive d'ailleurs : fichiers remis"

Set-TrustText ".claude/settings.json" '{"model": "opus", "env": {"A": "1"}, "hooks": {"SessionStart": [{"hooks": [{"type": "command", "command": "echo b"}]}]}}'
Set-TrustText ".claude.json" '{"numStartups": 2}'
$trAccs = @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" })
Assert-Equal ".claude/settings.json : env, hooks|.claude.json : mcpServers" ((Get-RestoreChanges $trZip $trAccs) -join "|") "restauration : reglages qui lancent des commandes compares"
Assert-Throws { Restore-Accounts $trZip } "--yes" "restauration : changements a confirmer"
Assert-True ([IO.File]::ReadAllText((Join-Path $script:HomeDir ".claude/settings.json")).Contains("echo b")) "restauration non confirmee : reglages intacts"
$null = Restore-Accounts $trZip -Yes
Assert-True ([IO.File]::ReadAllText((Join-Path $script:HomeDir ".claude/settings.json")).Contains("echo a")) "restauration confirmee : reglages remis"
Assert-Equal "" ((Get-RestoreChanges $trZip $trAccs) -join "|") "reglages identiques : rien a confirmer"
$trRows = @(Get-RestoreWarn @(".claude/settings.json : hooks"))
Assert-True (@($trRows | Where-Object { (@($_ | ForEach-Object { [string]$_[0] }) -join "").Contains(".claude/settings.json : hooks") }).Count -ge 1) "menu : changements montres avant confirmation"
Assert-True ((Get-CliHelpLines) -join "`n").Contains("--yes]") "aide : --yes cite pour la restauration"

$trBytes = [IO.File]::ReadAllBytes($trZip)
$trBytes[$trBytes.Length - 1] = $trBytes[$trBytes.Length - 1] -bxor 1
[IO.File]::WriteAllBytes($trZip, $trBytes)
Assert-True (-not (Test-BackupTrusted $trZip)) "archive modifiee : plus reconnue"

. (Join-Path $bin "menu/manage/claude-menu-archive.ps1")
Remove-Item Function:\Set-TrustText
Remove-Item -LiteralPath $trRoot -Recurse -Force
$script:HomeDir = $trHome
$script:RegistryPath = $trRegistry
