$dirSaved = $null
if (Test-Path -LiteralPath $script:RegistryPath) { $dirSaved = [IO.File]::ReadAllBytes($script:RegistryPath) }
foreach ($d in @(".claude", ".claude-compte2", ".claude-a_B-9")) { Assert-True (Test-AccountDir $d) ("dossier de compte accepte : " + $d) }
foreach ($d in @("", ".claudex", ".claude-", ".claude-a/b", ".claude-a\b", "../x", ".claude/..", ".claude-a.b", ".claude- a", "C:\x", ".claude-a`n", ".CLAUDE", 3)) {
  Assert-True (-not (Test-AccountDir $d)) ("dossier de compte refuse : [" + $d + "]")
}

[IO.File]::WriteAllText($script:RegistryPath, '[{"Label":"a","Dir":".claude"},{"Label":"b","Dir":"../evil"},{"Label":"c","Dir":".claude-c"},{"Label":"d","Dir":".claude-d/../../x"}]')
$dirWarn = @(Get-Accounts 3>&1 | Where-Object { $_ -is [Management.Automation.WarningRecord] })
$dirAccs = @(Get-Accounts 3>$null)
Assert-Equal ".claude|.claude-c" (($dirAccs | ForEach-Object { $_.Dir }) -join "|") "registre : dossiers refuses ecartes"
Assert-True ($dirWarn.Count -ge 2 -and $dirWarn[0].Message.Contains("../evil")) "registre : dossier refuse signale"

$dirBad = @([PSCustomObject]@{ Label = "a"; Dir = ".claude" }, [PSCustomObject]@{ Label = "x"; Dir = "../x" })
Assert-Equal ".claude|.claude.json|.mcp.json" ((Get-AccountItems $dirBad 3>$null) -join "|") "elements sauvegardes : dossiers refuses ecartes"
Assert-True (-not ((Get-SaveExcludes $dirBad 3>$null) -join "|").Contains("../x")) "exclusions de sauvegarde : dossiers refuses ecartes"

foreach ($p in @(".claude/a.md", ".claude-c/b.md", ".claude.json", ".mcp.json", ".claude-accounts.json")) { Assert-True (Test-SafeSyncPath $p) ("chemin de synchro accepte : " + $p) }
foreach ($p in @(".claudex/a.md", ".claude-a.b/x.md", ".claude/../x", ".claude/a\b", ".claude.json.x", ".autre/a.md", "")) { Assert-True (-not (Test-SafeSyncPath $p)) ("chemin de synchro refuse : " + $p) }
foreach ($k in @("upload", "delete-local", "download", "keep-remote")) {
  Assert-Throws { Invoke-SyncAction @{ Res = @{} } @{ Kind = $k; Path = ".claude/../x" } } (Get-ClmText "drive.action.unsafePath" @("")) ("synchro : " + $k + " refuse un chemin dangereux")
}

if ($null -ne $dirSaved) { [IO.File]::WriteAllBytes($script:RegistryPath, $dirSaved) } else { Remove-Item -LiteralPath $script:RegistryPath -Force }
