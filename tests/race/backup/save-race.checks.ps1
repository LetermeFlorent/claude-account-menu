$raceLab = Split-Path -Parent $PSScriptRoot
. (Join-Path $raceLab "race-helpers.ps1")

$svRoot = Join-Path $script:Sandbox "save-race"
$svGate = Join-Path $svRoot "gate"
$svDl = Join-Path $svRoot "downloads"
$svEnv = @{ USERPROFILE = $svRoot; HOME = $svRoot; LOCALAPPDATA = (Join-Path $svRoot "AppData"); XDG_STATE_HOME = (Join-Path $svRoot "state"); XDG_CONFIG_HOME = (Join-Path $svRoot "config") }
$null = New-Item -ItemType Directory -Path $svGate, $svDl, (Join-Path $svRoot ".claude"), (Join-Path $svRoot ".claude-compte2") -Force
[IO.File]::WriteAllText((Join-Path $svRoot ".claude/CLAUDE.md"), "regles")
[IO.File]::WriteAllText((Join-Path $svRoot ".claude.json"), "{}")
[IO.File]::WriteAllText((Join-Path $svRoot ".claude-compte2/CLAUDE.md"), "regles 2")
$svRegistry = Get-StatePath "accounts.json" $svEnv
[IO.File]::WriteAllText($svRegistry, '[{"Label":"compte1","Dir":".claude"},{"Label":"compte2","Dir":".claude-compte2"}]' + "`n")

$svChild = Join-Path $PSScriptRoot "save-child.ps1"
$svBase = @{ Bin = $bin; Lab = $raceLab; Dir = $svGate; Downloads = $svDl }
$svParams = @(foreach ($n in 1..3) { $svBase + @{ Id = ("s" + $n); Mode = "save" } })
$svRuns = Invoke-Race $svChild $svParams $svGate $svEnv
$svList = Wait-RaceChild (Start-RaceChild $svChild ($svBase + @{ Id = "list"; Mode = "list" }) $svEnv)

$svPaths = @(foreach ($r in $svRuns) { foreach ($line in ($r.Out -split "\r?\n")) { if ($line -match '^result \S+ (.+)$') { $Matches[1] } } })
$svUnique = @($svPaths | Sort-Object -Unique)
$svListed = @(foreach ($line in ($svList.Out -split "\r?\n")) { if ($line -match '^listed (.+)$') { $Matches[1] } })
$svIntact = @($svUnique | Where-Object { [IO.File]::Exists($_) -and (Test-ArchiveIntact $_) })
$svNamesListed = @($svUnique | Where-Object { $svListed -contains (Split-Path -Leaf $_) })
$svLeft = @(Get-ChildItem -LiteralPath $svDl -File | Where-Object { $_.Length -eq 0 -or $_.Name -like "*.tmp" })

Assert-Equal "" ((Format-RaceFailures ($svRuns + @($svList)))) "trois sauvegardes en meme temps : aucune erreur"
Assert-Equal 3 $svUnique.Count "trois sauvegardes en meme temps : trois archives distinctes"
Assert-Equal 3 $svIntact.Count "trois sauvegardes en meme temps : archives intactes"
Assert-Equal 3 $svNamesListed.Count "trois sauvegardes en meme temps : toutes listees"
Assert-Equal 0 $svLeft.Count "trois sauvegardes en meme temps : aucun fichier vide ou temporaire laisse"
