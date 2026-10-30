$fsRoot = Join-Path $script:Sandbox "fs-home"
$fsAccs = @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" }, [PSCustomObject]@{ Label = "compte2"; Dir = ".claude-compte2" })
$fsState = Join-Path $script:Sandbox "fs-etat"
$fsReg = Join-Path $fsState "accounts.json"
$null = New-Item -ItemType Directory -Path $fsState -Force
$fsCtx = New-WatchFsContext $fsRoot @(Get-SyncRoots $fsAccs) (Get-SyncPatterns $fsAccs) $fsReg

function Test-FsRel {
  param([string]$Rel)
  return Test-WatchPathRelevant (Join-Path $fsRoot $Rel) $fsCtx
}

Assert-True (Test-FsRel ".claude/settings.json") "reglage modifie : synchro"
Assert-True (Test-FsRel ".claude/skills/a/SKILL.md") "skill modifie : synchro"
Assert-True (Test-WatchPathRelevant $fsReg $fsCtx) "liste des comptes du dossier de clm : synchro"
Assert-True (Test-FsRel ".mcp.json") "MCP : synchro"
Assert-True (Test-FsRel ".claude-compte2/.credentials.json") "identifiants : synchro"
Assert-True (-not (Test-FsRel ".claude/projects/p/abc.jsonl")) "conversation : ignoree"
Assert-True (-not (Test-FsRel ".claude/node_modules/x/index.js")) "node_modules : ignore"
Assert-True (-not (Test-FsRel ".claude.json")) "config du compte : gardee pour la sortie"
Assert-True (-not (Test-FsRel ".claude-compte2/.claude.json")) "config du second compte : gardee pour la sortie"
Assert-True (-not (Test-WatchPathRelevant (Join-Path $fsState "drive-state.json") $fsCtx)) "autre fichier de clm : ignore"
Assert-True (-not (Test-FsRel ".claude-autre/x.md")) "dossier hors comptes : ignore"
Assert-True (-not (Test-WatchPathRelevant $fsRoot $fsCtx)) "dossier de base lui-meme : ignore"
Assert-True (-not (Test-WatchPathRelevant "" $fsCtx)) "chemin vide : ignore"

$kept = New-Object IO.RenamedEventArgs ([IO.WatcherChangeTypes]::Renamed), (Join-Path $fsRoot ".claude"), "x.tmp", "settings.json"
Assert-True (Test-WatchEventRelevant $kept $fsCtx) "renomme vers un fichier suivi : synchro"
$gone = New-Object IO.RenamedEventArgs ([IO.WatcherChangeTypes]::Renamed), (Join-Path $fsRoot ".claude"), "projects/p/a.jsonl", "settings.json"
Assert-True (Test-WatchEventRelevant $gone $fsCtx) "fichier suivi renomme ailleurs : synchro"
$both = New-Object IO.RenamedEventArgs ([IO.WatcherChangeTypes]::Renamed), (Join-Path $fsRoot ".claude"), "cache/b", "cache/a"
Assert-True (-not (Test-WatchEventRelevant $both $fsCtx)) "renommage dans un dossier ignore : rien"
Assert-True (Test-WatchEventRelevant (New-Object IO.ErrorEventArgs (New-Object IO.InternalBufferOverflowException)) $fsCtx) "trop de changements d'un coup : synchro"

$null = New-Item -ItemType Directory -Path (Join-Path $fsRoot ".claude/skills") -Force
$null = New-Item -ItemType Directory -Path (Join-Path $fsRoot ".claude/node_modules") -Force
$dirTouched = New-Object IO.FileSystemEventArgs ([IO.WatcherChangeTypes]::Changed), $fsRoot, ".claude"
Assert-True (-not (Test-WatchEventRelevant $dirTouched $fsCtx)) "dossier touche par un changement dedans : rien de plus"
$dirMoved = New-Object IO.FileSystemEventArgs ([IO.WatcherChangeTypes]::Created), (Join-Path $fsRoot ".claude"), "skills"
Assert-True (Test-WatchEventRelevant $dirMoved $fsCtx) "dossier arrive d'ailleurs : synchro"
Start-WatchFs $fsCtx
Assert-True (-not $fsCtx.Blind) "surveillance lancee"
Assert-Equal 3 @($fsCtx.Items).Count "base, dossier de clm et dossier du compte surveilles, dossier absent saute"
[IO.File]::WriteAllText((Join-Path $fsRoot ".claude/node_modules/x.js"), "x")
Start-Sleep -Milliseconds 500
Assert-True (-not (Receive-WatchEvents $fsCtx)) "changement ignore : pas de synchro"
[IO.File]::WriteAllText((Join-Path $fsRoot ".claude/skills/a.md"), "a")
Start-Sleep -Milliseconds 500
Assert-True (Receive-WatchEvents $fsCtx) "changement suivi vu"
Assert-True (-not (Receive-WatchEvents $fsCtx)) "changement compte une fois"
[IO.File]::WriteAllText((Join-Path $fsRoot ".mcp.json"), "{}")
Start-Sleep -Milliseconds 500
Assert-True (Receive-WatchEvents $fsCtx) "fichier a la base vu"
[IO.File]::WriteAllText((Join-Path $fsState "drive-state.json"), "{}")
Start-Sleep -Milliseconds 500
Assert-True (-not (Receive-WatchEvents $fsCtx)) "etat de clm modifie : pas de synchro"
[IO.File]::WriteAllText($fsReg, "[]")
Start-Sleep -Milliseconds 500
Assert-True (Receive-WatchEvents $fsCtx) "liste des comptes du dossier de clm vue"
Stop-WatchFs $fsCtx
Assert-Equal 0 @(Get-EventSubscriber | Where-Object { $_.SourceIdentifier.StartsWith($script:DriveWatchPrefix) }).Count "surveillance arretee"
Assert-Equal 0 @($fsCtx.Items).Count "surveillances liberees"
Stop-WatchFs $null

$missing = New-WatchFsContext (Join-Path $script:Sandbox "fs-absent") @(".claude") @()
Start-WatchFs $missing
Assert-True $missing.Blind "base absente : synchro reguliere a la place"
Stop-WatchFs $missing
