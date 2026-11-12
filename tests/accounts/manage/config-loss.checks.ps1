. (Join-Path $bin "sync/core/claude-sync.ps1")

$lossSavedRegistry = $null
if (Test-Path -LiteralPath $script:RegistryPath) { $lossSavedRegistry = [IO.File]::ReadAllBytes($script:RegistryPath) }
$lossSavedState = $null
if (Test-Path -LiteralPath $script:SyncStatePath) { $lossSavedState = [IO.File]::ReadAllBytes($script:SyncStatePath) }
$lossMain = Join-Path $script:HomeDir ".claude"
$lossMainFiles = @("CLAUDE.md", "settings.local.json", "statusline.json", "settings.json")
$lossSavedMain = @{}
foreach ($n in $lossMainFiles) {
  $p = Join-Path $lossMain $n
  if (Test-Path -LiteralPath $p) { $lossSavedMain[$n] = [IO.File]::ReadAllBytes($p); Remove-Item -LiteralPath $p -Force }
}
$lossSavedCfg = $null
$lossCfgPath = Join-Path $script:HomeDir ".claude.json"
if (Test-Path -LiteralPath $lossCfgPath) { $lossSavedCfg = [IO.File]::ReadAllBytes($lossCfgPath); Remove-Item -LiteralPath $lossCfgPath -Force }

function Set-LossFile {
  param([string]$Path, [string]$Text, [int]$AgeMinutes)
  $d = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
  [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding($false)))
  [IO.File]::SetLastWriteTimeUtc($Path, (Get-Date).ToUniversalTime().AddMinutes(-$AgeMinutes))
}

function Test-LossMarker {
  param([string[]]$Folders, [string]$Marker)
  foreach ($f in $Folders) {
    foreach ($file in @(Get-ChildItem -LiteralPath $f -File -Force -ErrorAction SilentlyContinue)) {
      if ([IO.File]::ReadAllText($file.FullName).Contains($Marker)) { return $true }
    }
  }
  return $false
}

function Remove-LossAccount {
  param([string]$Dir)
  $p = Join-Path $script:HomeDir $Dir
  if (-not (Test-Path -LiteralPath $p)) { return }
  foreach ($d in $script:SharedDirs) {
    $l = Join-Path $p $d
    if ((Test-Path -LiteralPath $l) -and (Get-Item -LiteralPath $l -Force).LinkType) { [IO.Directory]::Delete($l) }
  }
  Remove-Item -LiteralPath $p -Recurse -Force
}

$lossA = [PSCustomObject]@{ Label = "loss2"; Dir = ".claude-loss2" }
$lossB = [PSCustomObject]@{ Label = "loss3"; Dir = ".claude-loss3" }
$lossAPath = Join-Path $script:HomeDir $lossA.Dir

foreach ($n in @("CLAUDE.md", "settings.local.json", "statusline.json")) {
  Remove-LossAccount $lossA.Dir
  Set-LossFile (Join-Path $lossMain $n) ("MAIN-RICH-" + $n + "`nline two`nline three`nline four`nline five`n") 10
  Repair-SharedLinks $lossA
  $accFile = Join-Path $lossAPath $n
  Assert-True (Test-SameFile (Join-Path $lossMain $n) $accFile) ("perte config, " + $n + " : lien physique cree")
  Write-TextFileAtomic $accFile ("ACC-THIN-" + $n + "`n")
  Assert-True (-not (Test-SameFile (Join-Path $lossMain $n) $accFile)) ("perte config, " + $n + " : reecriture par fichier temporaire casse le lien")
  Repair-SharedLinks $lossA
  Assert-True (Test-LossMarker @($lossMain, $lossAPath) ("MAIN-RICH-" + $n)) ("perte config, " + $n + " : copie compte plus recente mais plus mince n'efface pas le contenu de main")
  Assert-True (Test-LossMarker @($lossMain, $lossAPath) ("ACC-THIN-" + $n)) ("perte config, " + $n + " : copie compte plus recente gardee")
}

foreach ($n in @("CLAUDE.md", "settings.local.json", "statusline.json")) {
  Remove-LossAccount $lossA.Dir
  Set-LossFile (Join-Path $lossMain $n) ("MAIN-NEWER-" + $n + "`n") 1
  Repair-SharedLinks $lossA
  $accFile = Join-Path $lossAPath $n
  Write-TextFileAtomic $accFile ("ACC-OLDER-" + $n + "`nonly in the account`n")
  [IO.File]::SetLastWriteTimeUtc($accFile, (Get-Date).ToUniversalTime().AddMinutes(-30))
  Repair-SharedLinks $lossA
  Assert-True (Test-LossMarker @($lossMain, $lossAPath) ("ACC-OLDER-" + $n)) ("perte config, " + $n + " : copie compte divergente plus ancienne sauvegardee, pas supprimee")
}

Remove-LossAccount $lossA.Dir
$null = New-SandboxFile ".claude/commands/main-cmd.md" "main"
$null = New-SandboxFile ".claude-loss2/commands/acc-only-cmd.md" "ACC-ONLY-CMD"
Repair-SharedLinks $lossA
Assert-True ([bool](Get-Item -LiteralPath (Join-Path $lossAPath "commands") -Force).LinkType) "perte config, commands : relie a main"
Assert-True (Test-Path -LiteralPath (Join-Path $lossAPath "commands/acc-only-cmd.md")) "perte config, commands : fichier du compte reste visible apres le lien"
Assert-True (Test-Path -LiteralPath (Join-Path $lossMain "commands/acc-only-cmd.md")) "perte config, commands : fichier du compte fusionne dans main"

Remove-LossAccount $lossA.Dir
$null = New-SandboxFile ".claude-loss2/commands/acc-second.md" "ACC-SECOND"
$null = New-SandboxFile ".claude-loss2/commands.bak-sync/old.md" "OLD-BACKUP"
Repair-SharedLinks $lossA 3>$null
Assert-True ([bool](Get-Item -LiteralPath (Join-Path $lossAPath "commands") -Force).LinkType) "perte config, commands.bak-sync existe deja : le dossier du compte est quand meme relie"
Assert-True (Test-Path -LiteralPath (Join-Path $lossAPath "commands/acc-second.md")) "perte config, commands.bak-sync existe deja : fichier du compte reste visible"

Remove-LossAccount $lossA.Dir
Remove-LossAccount $lossB.Dir
Save-Registry @([PSCustomObject]@{ Label = "main"; Dir = ".claude" }, $lossA, $lossB)
if (Test-Path -LiteralPath $script:SyncStatePath) { Remove-Item -LiteralPath $script:SyncStatePath -Force }
$richSettings = '{"model":"opus","env":{"K":"v"},"permissions":{"defaultMode":"bypassPermissions"},"hooks":{"SessionStart":[{"matcher":"startup"}]}}'
$lossSetMain = New-SandboxFile ".claude/settings.json" $richSettings
$lossSetA = New-SandboxFile ".claude-loss2/settings.json" $richSettings
$lossSetB = New-SandboxFile ".claude-loss3/settings.json" $richSettings
$richCfg = '{"oauthAccount":{"emailAddress":"m@x"},"mcpServers":{"ctx":{"command":"npx"},"fs":{"command":"node"}}}'
$lossCfgMain = New-SandboxFile ".claude.json" $richCfg
$lossCfgA = New-SandboxFile ".claude-loss2/.claude.json" '{"oauthAccount":{"emailAddress":"a@x"},"mcpServers":{"ctx":{"command":"npx"},"fs":{"command":"node"}}}'
$lossCfgB = New-SandboxFile ".claude-loss3/.claude.json" '{"oauthAccount":{"emailAddress":"b@x"},"mcpServers":{"ctx":{"command":"npx"},"fs":{"command":"node"}}}'
Sync-Accounts
Assert-Equal 2 @((Read-JsonFile $lossCfgA)["mcpServers"].Keys).Count "perte config, base de synchro : mcpServers de depart"

Write-TextFileAtomic $lossSetA '{"model":"sonnet","theme":"dark"}'
[IO.File]::SetLastWriteTimeUtc($lossSetA, (Get-Date).ToUniversalTime().AddMinutes(10))
Write-TextFileAtomic $lossCfgA '{"oauthAccount":{"emailAddress":"a2@x"},"numStartups":1}'
[IO.File]::SetLastWriteTimeUtc($lossCfgA, (Get-Date).ToUniversalTime().AddMinutes(10))
Sync-Accounts
foreach ($pair in @(@("main", $lossSetMain), @("compte 3", $lossSetB))) {
  $r = Read-JsonFile $pair[1]
  Assert-True ($r.Keys -contains "hooks") ("perte config, " + $pair[0] + " : settings.json mince et recent n'efface pas hooks")
  Assert-True ($r.Keys -contains "permissions") ("perte config, " + $pair[0] + " : settings.json mince et recent n'efface pas permissions")
  Assert-True ($r.Keys -contains "env") ("perte config, " + $pair[0] + " : settings.json mince et recent n'efface pas env")
}
foreach ($pair in @(@("main", $lossCfgMain), @("compte 3", $lossCfgB))) {
  $r = Read-JsonFile $pair[1]
  Assert-Equal 2 @($r["mcpServers"].Keys).Count ("perte config, " + $pair[0] + " : .claude.json sans mcpServers n'efface pas les serveurs")
}

Remove-LossAccount $lossA.Dir
Remove-LossAccount $lossB.Dir
foreach ($n in $lossMainFiles) { $p = Join-Path $lossMain $n; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force }; if ($lossSavedMain.ContainsKey($n)) { [IO.File]::WriteAllBytes($p, $lossSavedMain[$n]) } }
if (Test-Path -LiteralPath $lossCfgPath) { Remove-Item -LiteralPath $lossCfgPath -Force }
if ($null -ne $lossSavedCfg) { [IO.File]::WriteAllBytes($lossCfgPath, $lossSavedCfg) }
foreach ($n in @("commands/main-cmd.md", "commands/acc-only-cmd.md")) { $p = Join-Path $lossMain $n; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force } }
if ($null -ne $lossSavedRegistry) { [IO.File]::WriteAllBytes($script:RegistryPath, $lossSavedRegistry) } else { Remove-Item -LiteralPath $script:RegistryPath -Force -ErrorAction SilentlyContinue }
if ($null -ne $lossSavedState) { [IO.File]::WriteAllBytes($script:SyncStatePath, $lossSavedState) } else { Remove-Item -LiteralPath $script:SyncStatePath -Force -ErrorAction SilentlyContinue }
