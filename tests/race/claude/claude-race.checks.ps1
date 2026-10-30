$raceLab = Split-Path -Parent $PSScriptRoot
. (Join-Path $raceLab "race-helpers.ps1")

$claudeRoot = Join-Path $script:Sandbox "claude-race"
New-Item -ItemType Directory -Path $claudeRoot -Force | Out-Null
$claudeEnv = @{ USERPROFILE = $claudeRoot; HOME = $claudeRoot; LOCALAPPDATA = (Join-Path $claudeRoot "AppData"); XDG_STATE_HOME = (Join-Path $claudeRoot "state"); CLAUDE_CONFIG_DIR = $null }
$claudeChild = Join-Path $PSScriptRoot "claude-child.ps1"
$claudeParams = @(foreach ($n in 1..3) { @{ Bin = $bin; Lab = $raceLab; Dir = $claudeRoot; Id = ("c" + $n) } })
$claudeRuns = Invoke-Race $claudeChild $claudeParams $claudeRoot $claudeEnv
$claudeOut = @(foreach ($r in $claudeRuns) { @($r.Out -split "`r?`n" | Where-Object { $_ -like "result *" -or $_ -like "stamp *" }) }) -join "|"
Assert-Equal "" (Format-RaceFailures $claudeRuns) "trois clm mettent Claude Code a jour en meme temps : aucune erreur"
Assert-Equal 1 @(Get-ChildItem -LiteralPath $claudeRoot -Filter "run-*").Count "trois clm mettent Claude Code a jour en meme temps : une seule mise a jour"
Assert-Equal ((@(foreach ($n in 1..3) { "result c" + $n + " done ok " + ((Get-ClmText "update.claude.upToDateVersion" @("2.1.300")) -replace "^Claude Code ", "") + "|stamp 2.1.300" })) -join "|") $claudeOut "trois clm mettent Claude Code a jour en meme temps : chacun finit a jour, marque intacte"
Assert-True (-not ((@($claudeRuns | ForEach-Object { $_.Out }) -join " ") -match "echec|impossible")) "trois clm mettent Claude Code a jour en meme temps : aucun message d'echec"
