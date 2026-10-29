$raceLab = Split-Path -Parent $PSScriptRoot
. (Join-Path $raceLab "race-helpers.ps1")

$hookRoot = Join-Path $script:Sandbox "hook-race"
$hookEnv = @{ USERPROFILE = $hookRoot; HOME = $hookRoot; LOCALAPPDATA = (Join-Path $hookRoot "AppData"); XDG_STATE_HOME = (Join-Path $hookRoot "state"); XDG_CONFIG_HOME = (Join-Path $hookRoot "config") }
$hookState = Get-StatusStatePath -Vars $hookEnv
New-Item -ItemType Directory -Force -Path (Split-Path $hookState) | Out-Null
[IO.File]::WriteAllText($hookState, "theme dark`nq5_at@autre 5`n", (New-Object Text.UTF8Encoding($false)))

$hookChild = Join-Path $PSScriptRoot "hook-child.ps1"
$hookAccounts = @{ "claude" = ".claude"; "claude-compte2" = ".claude-compte2"; "claude-compte3" = ".claude-compte3" }
$hookParams = @(foreach ($tag in ($hookAccounts.Keys | Sort-Object)) { @{ Bin = $bin; Lab = $raceLab; Dir = $hookRoot; Id = $tag; Account = $hookAccounts[$tag]; Rounds = 3 } })
$hookRuns = Invoke-Race $hookChild $hookParams $hookRoot $hookEnv
Assert-Equal "" (Format-RaceFailures $hookRuns) "trois crochets de session en meme temps : aucune erreur"

$hookLines = @(Merge-StatusChanges @([IO.File]::ReadAllText($hookState).TrimEnd("`n").Split("`n")) @(Get-StatusChanges $hookState))
foreach ($tag in ($hookAccounts.Keys | Sort-Object)) {
  foreach ($key in "q5_at", "q5_pct", "q7_at", "q7_pct", "q_at") {
    $found = @($hookLines | Where-Object { $_ -match ("^" + $key + "@" + [regex]::Escape($tag) + " ") }).Count
    Assert-Equal 1 $found ("trois crochets de session en meme temps : toutes les entrees presentes (" + $key + "@" + $tag + ")")
  }
}
Assert-True ($hookLines -contains "theme dark" -and $hookLines -contains "q5_at@autre 5") "trois crochets de session en meme temps : lignes de claude-statusline gardees"
Assert-Equal 0 @($hookLines | Where-Object { $_ -notmatch '^\S+ \S+$' }).Count "trois crochets de session en meme temps : fichier intact"
Assert-Equal 0 @(Get-ChildItem -LiteralPath (Split-Path $hookState) -Filter "*.tmp").Count "trois crochets de session en meme temps : aucun fichier temporaire laisse"
