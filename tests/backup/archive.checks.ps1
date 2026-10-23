. (Join-Path $bin "claude-menu-archive.ps1")
. (Join-Path $bin "claude-self-version.ps1")
. (Join-Path $bin "claude-menu-save.ps1")
. (Join-Path $bin "claude-menu-remove.ps1")
$backupHome = $script:HomeDir
$backupRegistry = $script:RegistryPath
$script:HomeDir = Join-Path $script:Sandbox "maison sauvegarde"
$script:RegistryPath = Join-Path (Join-Path $script:Sandbox "etat sauvegarde") "accounts.json"
$script:BackupDl = Join-Path $script:Sandbox "dl (1)"
$null = New-Item -ItemType Directory -Path $script:HomeDir, $script:BackupDl, (Split-Path -Parent $script:RegistryPath) -Force
function Get-DownloadsDir { return $script:BackupDl }
function Set-HomeText { param([string]$Rel, [string]$Text) $null = New-SandboxFile ("maison sauvegarde/" + $Rel) $Text }
function Get-HomeText {
  param([string]$Rel)
  $p = Join-Path $script:HomeDir $Rel
  if (-not (Test-Path -LiteralPath $p)) { return $null }
  return [IO.File]::ReadAllText($p)
}

$team = [string][char]0xC9 + "quipe"
Save-Registry @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" }, [PSCustomObject]@{ Label = $team; Dir = ".claude-compte2" })
Set-HomeText ".claude/.credentials.json" "A1"
Set-HomeText ".claude/skills/outil/SKILL.md" "outil"
Set-HomeText ".claude/skills/.trash/vieux/SKILL.md" "t"
Set-HomeText ".claude/projects/p/conv.jsonl" "c"
Set-HomeText ".claude/projects/p/memory/note.md" "n"
Set-HomeText ".claude/cache/x" "x"
Set-HomeText ".claude/CLAUDE.md" "regles"
Set-HomeText ".claude.json" "{}"
Set-HomeText ".claude-compte2/.credentials.json" "B1"
foreach ($a in Get-Accounts) { Repair-SharedLinks $a -Force }

$first = Save-Accounts
$zip = @(Get-Backups)[0].FullName
$names = @(& $script:Tar -tf $zip)
Assert-True ($first.StartsWith($zip + " (")) "sauvegarde : chemin de l'archive rendu"
Assert-True (($names -contains ".claude/skills/outil/SKILL.md") -and ($names -contains ".claude/projects/p/memory/note.md") -and ($names -contains ".claude.json") -and ($names -contains ".claude-compte2/.credentials.json")) "sauvegarde : fichiers des comptes"
Assert-Equal 0 @($names | Where-Object { $_ -match '\.trash|\.jsonl$|/cache/|^\.claude-compte2/(skills|CLAUDE\.md)' }).Count "sauvegarde : caches, conversations et liens partages exclus"
Assert-Equal ("compte1|" + $team) ((@(Get-ZipAccounts $zip) | ForEach-Object { $_.Label }) -join "|") "sauvegarde : noms des comptes relus"
Assert-Equal ".claude-accounts.json" ((@($names | Where-Object { $_ -like "*accounts.json" })) -join "|") "sauvegarde : liste des comptes a la racine, sous son ancien nom"
Assert-Equal 0 @(Get-ChildItem -LiteralPath ([IO.Path]::GetTempPath()) -Filter "claude-reg-*" -Directory).Count "sauvegarde : copie de la liste effacee"

$taken = Join-Path $script:BackupDl "claude-comptes-pris.zip"
[IO.File]::WriteAllText($taken, "")
Assert-Equal (Join-Path $script:BackupDl "claude-comptes-pris-2.zip") (Get-FreeArchivePath "claude-comptes-pris" ".zip") "nom deja pris : archive voisine, jamais ecrasee"
Remove-Item -LiteralPath $taken

$cut = Join-Path $script:Sandbox ("coupee" + (Get-ArchiveExtension $script:TarFlavor))
$bytes = [IO.File]::ReadAllBytes($zip)
[IO.File]::WriteAllBytes($cut, [byte[]]$bytes[0..([int]($bytes.Length / 2))])
Assert-True (Test-ArchiveIntact $zip) "archive entiere : lisible"
Assert-True (-not (Test-ArchiveIntact $cut)) "archive coupee : reconnue illisible"
Remove-Item -LiteralPath $cut

Set-HomeText ".claude/.credentials.json" "A2"
Remove-Item -LiteralPath (Join-Path $script:HomeDir ".claude/skills/outil") -Recurse -Force
Set-HomeText ".claude-compte2/.credentials.json" "B2"
$msg = Restore-Accounts $zip
Assert-Equal "A1|B1|outil|regles" (@((Get-HomeText ".claude/.credentials.json"), (Get-HomeText ".claude-compte2/.credentials.json"), (Get-HomeText ".claude/skills/outil/SKILL.md"), (Get-HomeText ".claude-compte2/CLAUDE.md")) -join "|") "restauration : fichiers remis, partages relies"
$safe = @(Get-Backups | Where-Object { $_.Name -like "claude-comptes-avant-restauration-*" })
Assert-Equal 1 $safe.Count "restauration : etat d'avant sauvegarde"
Assert-True ($safe.Count -eq 1 -and $msg.EndsWith("Etat precedent garde dans " + $safe[0].Name)) ("restauration : copie citee par son nom, " + $msg)

Save-Registry @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" })
Remove-LinkOrTree (Join-Path $script:HomeDir ".claude-compte2")
$null = Restore-Accounts $zip @(Get-ZipAccounts $zip | Where-Object { $_.Dir -eq ".claude-compte2" })
Assert-Equal $team ((@(Get-Accounts | Where-Object { $_.Dir -eq ".claude-compte2" }) | ForEach-Object { $_.Label }) -join "|") "compte absent : remis au menu sous son nom"
Assert-Equal "B1|regles" (@((Get-HomeText ".claude-compte2/.credentials.json"), (Get-HomeText ".claude-compte2/CLAUDE.md")) -join "|") "compte absent : fichiers remis et relies"
Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:HomeDir ".claude-accounts.json"))) "restauration : rien ecrit sous l'ancien nom du dossier perso"

$null = New-SandboxFile "ancienne/.claude-accounts.json" '[{ "Label": "vieux", "Dir": ".claude-compte3" }]'
$null = New-SandboxFile "ancienne/.claude-compte3/.credentials.json" "C1"
$old = Join-Path $script:BackupDl ("claude-comptes-ancienne" + (Get-ArchiveExtension $script:TarFlavor))
& $script:Tar -a -c -f $old -C (Join-Path $script:Sandbox "ancienne") ".claude-accounts.json" ".claude-compte3"
Assert-Equal "vieux" ((@(Get-ZipAccounts $old) | ForEach-Object { $_.Label }) -join "|") "ancienne archive : noms des comptes relus"
$null = Restore-Accounts $old
Assert-Equal "C1" (Get-HomeText ".claude-compte3/.credentials.json") "ancienne archive : compte remis"
Assert-True ([IO.File]::ReadAllText($script:RegistryPath).Contains("vieux")) "ancienne archive : liste ecrite dans le dossier de clm"
Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:HomeDir ".claude-accounts.json"))) "ancienne archive : liste hors du dossier perso"

$null = New-SandboxFile "intrus/Documents/a.txt" "x"
$empty = Join-Path $script:BackupDl ("claude-comptes-vide" + (Get-ArchiveExtension $script:TarFlavor))
& $script:Tar -a -c -f $empty -C (Join-Path $script:Sandbox "intrus") "Documents"
foreach ($pick in @($null, @(), @([PSCustomObject]@{ Label = "x"; Dir = ".claude-compte9" }))) {
  $err = $null
  try { $null = Restore-Accounts $empty $pick } catch { $err = $_.Exception.Message }
  Assert-Equal "aucun compte a restaurer dans cette sauvegarde" $err "archive sans ce compte : refusee"
}
Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:HomeDir "Documents"))) "archive sans compte : rien ecrit dans le dossier perso"

. (Join-Path $bin "claude-menu-archive.ps1")
Remove-LinkOrTree $script:HomeDir
Remove-Item -LiteralPath $script:BackupDl, (Join-Path $script:Sandbox "intrus"), (Join-Path $script:Sandbox "ancienne"), (Split-Path -Parent $script:RegistryPath) -Recurse -Force
$script:HomeDir = $backupHome
$script:RegistryPath = $backupRegistry
