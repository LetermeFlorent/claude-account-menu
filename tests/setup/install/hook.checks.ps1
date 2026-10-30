$hookHome = Join-Path $script:Sandbox "hook-home"
$hookCmd = ConvertTo-JsonString (Get-SeedHookCommand $script:OsName)
$goodText = '{"hooks": {"SessionStart": [{"hooks": [{"type": "command", "command": ' + $hookCmd + '}]}]}}'
$stalePath = New-SandboxFile "hook-home/.claude/settings.json" '{"hooks": {"SessionStart": [{"hooks": [{"type": "command", "command": "powershell -File \"C:/Users/perso/.local/bin/claude-statusline-seed.ps1\""}]}]}}'
$nonePath = New-SandboxFile "hook-home/.claude-compte2/settings.json" '{"model": "opus"}'
$goodPath = New-SandboxFile "hook-home/.claude-compte3/settings.json" $goodText
$savedProfile = $env:USERPROFILE
$savedHome = $env:HOME
$env:USERPROFILE = $hookHome
$env:HOME = $hookHome
try { & (Join-Path (Split-Path -Parent $bin) "install-hook.ps1") 6>$null } finally { $env:USERPROFILE = $savedProfile; $env:HOME = $savedHome }
Assert-Equal $goodText ([IO.File]::ReadAllText($stalePath)) "hook d'un autre PC remplace par celui de ce PC"
Assert-True (Test-Path -LiteralPath ($stalePath + ".bak-seed")) "copie gardee avant remplacement"
$added = [IO.File]::ReadAllText($nonePath) | ConvertFrom-Json
Assert-Equal (Get-SeedHookCommand $script:OsName) $added.hooks.SessionStart[0].hooks[0].command "hook ajoute quand il manque"
Assert-Equal "opus" $added.model "reglages gardes a l'ajout du hook"
Assert-Equal $goodText ([IO.File]::ReadAllText($goodPath)) "hook deja juste : fichier intact"
Assert-True (-not (Test-Path -LiteralPath ($goodPath + ".bak-seed"))) "hook deja juste : aucune copie"
Assert-True ($added.hooks.SessionStart[0].hooks[0].command -match '^(?:[A-Za-z]:/|/)\S+ -NoProfile ') "hook : interpreteur par chemin absolu"
Assert-True ($added.hooks.SessionStart[0].hooks[0].command.Contains('"$HOME/.local/bin/claude-statusline-seed.ps1"')) "hook : script sous le dossier perso de chaque PC"
