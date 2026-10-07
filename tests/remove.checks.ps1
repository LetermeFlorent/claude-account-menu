. (Join-Path $bin "claude-menu-remove.ps1")

# Ni archive dans les vrais Telechargements, ni trousseau du poste
$script:Archived = @()
$script:KeychainCleared = @()
function Save-Accounts { param([string]$Tag, $Accs) $script:Archived += @($Accs | ForEach-Object { $_.Dir }); return "archive.zip" }
function Remove-KeychainCredential { param([string]$ConfigDir) $script:KeychainCleared += $ConfigDir }

Assert-True (Test-ErasableDir ".claude-compte2") "effacable : .claude-compte2"
Assert-True (-not (Test-ErasableDir ".claude")) "protege : .claude"
Assert-True (-not (Test-ErasableDir ".claude-..")) "protege : .claude-.."
Assert-True (-not (Test-ErasableDir ".claude-a/../b")) "protege : chemin avec slash"
Assert-True (-not (Test-ErasableDir "Documents")) "protege : dossier quelconque"

$skill = New-SandboxFile ".claude/skills/demo/SKILL.md" "skill"
$rules = New-SandboxFile ".claude/CLAUDE.md" "regles"
$acc1 = [PSCustomObject]@{ Label = "compte1"; Dir = ".claude" }
$acc2 = [PSCustomObject]@{ Label = "pro"; Dir = ".claude-compte2" }
$acc3 = [PSCustomObject]@{ Label = "perso"; Dir = ".claude-compte3" }
Repair-SharedLinks $acc2
$null = New-SandboxFile ".claude-compte2/.credentials.json" "{}"
$ro = New-SandboxFile ".claude-compte2/projects/p/s.jsonl" "x"
(Get-Item -LiteralPath $ro).IsReadOnly = $true
$null = New-SandboxFile ".claude-compte3/.credentials.json" "{}"
Save-Registry @($acc1, $acc2, $acc3)
$dir2 = Get-AccountPath $acc2
$dir3 = Get-AccountPath $acc3

$msg = Remove-Account $acc3 $false
Assert-Equal "perso retire du menu" $msg "retrait simple, message"
Assert-True (Test-Path -LiteralPath $dir3) "retrait simple, dossier garde"
Assert-Equal ".claude|.claude-compte2" ((@(Get-Accounts) | ForEach-Object { $_.Dir }) -join "|") "retrait simple, registre"
Assert-Equal 0 $script:Archived.Count "retrait simple, pas d'archive"

$err = $null
try { $null = Remove-Account $acc1 $true } catch { $err = $_.Exception.Message }
Assert-Equal "le dossier .claude n'est jamais efface" $err "effacement de .claude refuse"
Assert-Equal ".claude|.claude-compte2" ((@(Get-Accounts) | ForEach-Object { $_.Dir }) -join "|") "refus, registre intact"

$msg = Remove-Account $acc2 $true
Assert-Equal "pro retire du menu, dossier efface, archive : archive.zip" $msg "effacement, message"
Assert-Equal ".claude-compte2" ($script:Archived -join "|") "effacement, archive du seul compte retire"
Assert-True (-not (Test-Path -LiteralPath $dir2)) "effacement, dossier parti"
Assert-Equal "skill" ([IO.File]::ReadAllText($skill)) "effacement, cible du lien skills intacte"
Assert-Equal "regles" ([IO.File]::ReadAllText($rules)) "effacement, lien dur CLAUDE.md intact"
Assert-Equal ".claude" ((@(Get-Accounts) | ForEach-Object { $_.Dir }) -join "|") "effacement, registre"
if ($script:OsName -eq "MacOS") { Assert-Equal $dir2 ($script:KeychainCleared -join "|") "effacement, trousseau du compte" }
else { Assert-Equal 0 $script:KeychainCleared.Count "pas de trousseau hors macOS" }

$err = $null
try { $null = Remove-Account $acc1 $false } catch { $err = $_.Exception.Message }
Assert-Equal "c'est le dernier compte" $err "dernier compte refuse"
Assert-Equal ".claude" ((@(Get-Accounts) | ForEach-Object { $_.Dir }) -join "|") "dernier compte, registre intact"

Remove-Item -LiteralPath $script:RegistryPath, $dir3 -Recurse -Force
Remove-Item Function:\Save-Accounts, Function:\Remove-KeychainCredential
