. (Join-Path $bin "sync/core/claude-sync.ps1")

$savedRegistry = $null
if (Test-Path -LiteralPath $script:RegistryPath) { $savedRegistry = [IO.File]::ReadAllText($script:RegistryPath) }
$s1 = [PSCustomObject]@{ Label = "s1"; Dir = ".claude" }
$s2 = [PSCustomObject]@{ Label = "s2"; Dir = ".claude-sync2" }
$s3 = [PSCustomObject]@{ Label = "s3"; Dir = ".claude-sync3" }
Save-Registry @($s1, $s2, $s3)
$set1 = New-SandboxFile ".claude/settings.json" '{"model":"opus","theme":"dark","enabledPlugins":{"a":false}}'
$set2 = New-SandboxFile ".claude-sync2/settings.json" '{"model":"sonnet","enabledPlugins":{"a":true}}'
$set3 = New-SandboxFile ".claude-sync3/settings.json" '{"model":"haiku","enabledPlugins":{"a":false}}'
[IO.File]::SetLastWriteTimeUtc($set2, (Get-Date).ToUniversalTime().AddMinutes(5))
$cfg1 = New-SandboxFile ".claude.json" '{"oauthAccount":{"emailAddress":"a@x"},"mcpServers":{"ctx":{"command":"npx"}}}'
$cfg2 = New-SandboxFile ".claude-sync2/.claude.json" '{"oauthAccount":{"emailAddress":"b@x"}}'
$cfg3 = New-SandboxFile ".claude-sync3/.claude.json" '{"projects":{"C:/a":1,"c:/a":2}}'
[IO.File]::SetLastWriteTimeUtc($cfg1, (Get-Date).ToUniversalTime().AddMinutes(9))
$null = New-SandboxFile ".claude/statusline.json" "ancien"
$local2 = New-SandboxFile ".claude-sync2/statusline.json" "recent"
[IO.File]::SetLastWriteTimeUtc($local2, (Get-Date).ToUniversalTime().AddMinutes(3))
$null = New-SandboxFile ".claude/plugins/installed_plugins.json" "{}"
$null = New-SandboxFile ".claude-sync2/plugins/installed_plugins.json" "{}"

Sync-Accounts
$r1 = Read-JsonFile $set1; $r3 = Read-JsonFile $set3
Assert-Equal $true $r1["enabledPlugins"]["a"] "sync settings, le plus recent gagne"
Assert-Equal "opus" $r1["model"] "sync settings, model propre au compte"
Assert-Equal "dark" $r1["theme"] "sync settings, theme propre au compte"
Assert-Equal "haiku" $r3["model"] "sync settings, model du compte 3"
Assert-Equal "npx" (Read-JsonFile $cfg2)["mcpServers"]["ctx"]["command"] "sync mcp, serveur copie"
Assert-Equal "b@x" (Read-JsonFile $cfg2)["oauthAccount"]["emailAddress"] "sync mcp, compte intact"
Assert-Equal 2 (Read-JsonFile $cfg3)["projects"]["c:/a"] "sync mcp, cles a casse differente gardees"
Assert-Equal "recent" ([IO.File]::ReadAllText((Join-Path $script:Sandbox ".claude/statusline.json"))) "lien physique repare, version recente gardee"
Assert-True (Test-SameFile (Join-Path $script:Sandbox ".claude/statusline.json") $local2) "lien physique recree"
Assert-True ([bool](Get-Item -LiteralPath (Join-Path $script:Sandbox ".claude-sync2/plugins") -Force).LinkType) "plugins relie"
Assert-True (Test-Path -LiteralPath (Join-Path $script:Sandbox ".claude-sync2/plugins.bak-sync")) "plugins sauvegarde"

[IO.File]::WriteAllText($set3, '{"model":"haiku","enabledPlugins":{"a":"c3"}}')
[IO.File]::SetLastWriteTimeUtc($set3, (Get-Date).ToUniversalTime().AddMinutes(20))
Sync-Accounts
Assert-Equal "c3" (Read-JsonFile $set1)["enabledPlugins"]["a"] "sync settings, modification suivante propagee"
Assert-Equal "sonnet" (Read-JsonFile $set2)["model"] "sync settings, model garde au second tour"

$savedLockWait = $script:SyncLockWaitMs
$script:SyncLockWaitMs = 0
$held = Open-MachineLock "sync"
try {
  [IO.File]::WriteAllText($set2, '{"model":"sonnet","enabledPlugins":{"a":"bloque"}}')
  [IO.File]::SetLastWriteTimeUtc($set2, (Get-Date).ToUniversalTime().AddMinutes(30))
  $shown = Sync-Accounts *>&1 | Out-String
  Assert-Equal "c3" (Read-JsonFile $set1)["enabledPlugins"]["a"] "verrou tenu, pas de sync"
  Assert-Equal "" $shown "verrou tenu : rien affiche"
} finally { Close-MachineLock $held }
$script:SyncLockWaitMs = $savedLockWait

if ($null -ne $savedRegistry) { [IO.File]::WriteAllText($script:RegistryPath, $savedRegistry) } else { Remove-Item -LiteralPath $script:RegistryPath -Force }
