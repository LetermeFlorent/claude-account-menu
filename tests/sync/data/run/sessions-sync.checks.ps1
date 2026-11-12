. (Join-Path $bin "sync/core/claude-sessions-sync.ps1")

$sesAccs = @([PSCustomObject]@{ Label = "s1"; Dir = ".claude-ses1" }, [PSCustomObject]@{ Label = "s2"; Dir = ".claude-ses2" }, [PSCustomObject]@{ Label = "s3"; Dir = ".claude-ses3" })
$sesRoots = @(foreach ($a in $sesAccs) { Join-Path $script:Sandbox ($a.Dir + "/projects/C--p") })
$null = New-SandboxFile ".claude-ses1/projects/C--p/aaa.jsonl" "line1`nline2`n"
$null = New-SandboxFile ".claude-ses2/projects/C--p/aaa.jsonl" "line1`n"
$null = New-SandboxFile ".claude-ses2/projects/C--p/bbb.jsonl" "b-only`n"
$null = New-SandboxFile ".claude-ses3/projects/C--p/aaa.jsonl" "other`n"
$null = New-SandboxFile ".claude-ses3/projects/C--p/memory/MEMORY.md" "mem`n"
$null = New-SandboxFile ".claude-ses1/projects/C--p/aaa/subagents/x.jsonl" "sub`n"

Assert-True (-not (Test-SessionSyncOn)) "sessions partagees : coupe par defaut"
Set-SessionSync $true
Assert-True (Test-SessionSyncOn) "sessions partagees : reglage garde"

$n = Sync-AccountSessions $sesAccs
$read = { param($i, $rel) $p = Join-Path $sesRoots[$i] $rel; if (Test-Path -LiteralPath $p) { [IO.File]::ReadAllText($p) } else { "<absent>" } }
Assert-Equal "line1`nline2`n" (& $read 1 "aaa.jsonl") "sessions partagees : copie plus courte prolongee"
Assert-Equal "other`n" (& $read 2 "aaa.jsonl") "sessions partagees : copie divergente jamais ecrasee"
Assert-Equal "b-only`n" (& $read 0 "bbb.jsonl") "sessions partagees : session manquante copiee"
Assert-Equal "b-only`n" (& $read 2 "bbb.jsonl") "sessions partagees : session copiee dans chaque compte"
Assert-Equal "mem`n" (& $read 0 "memory/MEMORY.md") "sessions partagees : memoire copiee"
Assert-Equal "sub`n" (& $read 2 "aaa/subagents/x.jsonl") "sessions partagees : sous-dossiers copies"
Assert-Equal "line1`nline2`n" (& $read 0 "aaa.jsonl") "sessions partagees : source intacte"
Assert-Equal 0 (Sync-AccountSessions $sesAccs) "sessions partagees : deuxieme passage sans copie"
Assert-True ($n -gt 0) "sessions partagees : copies comptees"
Assert-Equal 0 @(Get-ChildItem -LiteralPath (Join-Path $script:Sandbox ".claude-ses2") -Recurse -Filter ("*" + $script:SessionTmpExt)).Count "sessions partagees : aucun fichier temporaire"

Set-SessionSync $false
Assert-True (-not (Test-SessionSyncOn)) "sessions partagees : recoupe"
Remove-Item -LiteralPath $script:SessionSyncPath -Force -ErrorAction SilentlyContinue
foreach ($a in $sesAccs) { Remove-Item -LiteralPath (Join-Path $script:Sandbox $a.Dir) -Recurse -Force -ErrorAction SilentlyContinue }
