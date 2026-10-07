$ErrorActionPreference = "Stop"
$src = Join-Path $PSScriptRoot "bin"
$dst = Join-Path $env:USERPROFILE ".local\bin"
if (-not (Test-Path -LiteralPath $dst)) { New-Item -ItemType Directory -Path $dst | Out-Null }
Get-ChildItem -LiteralPath $src -File | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $dst -Force }
Write-Host ("scripts copies dans " + $dst)

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (($userPath -split ";") -notcontains $dst) {
  [Environment]::SetEnvironmentVariable("Path", ($userPath.TrimEnd(";") + ";" + $dst), "User")
  Write-Host "dossier ajoute au PATH utilisateur, ouvre un nouveau terminal pour utiliser clm"
}

if (-not (Test-Path -LiteralPath (Join-Path $env:SystemRoot "System32\tar.exe"))) {
  Write-Host "tar.exe absent : la sauvegarde demande Windows 10 1803 ou plus recent" -ForegroundColor Yellow
}
$claude = Join-Path $dst "claude.exe"
if (-not (Test-Path -LiteralPath $claude) -and -not (Get-Command claude -ErrorAction SilentlyContinue)) {
  Write-Host "Claude Code introuvable : installe-le d'abord, puis relance clm" -ForegroundColor Yellow
}
$seed = (Join-Path $dst "claude-statusline-seed.ps1").Replace("\", "/")
$hookCmd = 'powershell -NoProfile -ExecutionPolicy Bypass -File "' + $seed + '"'
$dirs = @(Join-Path $env:USERPROFILE ".claude") + @(Get-ChildItem -LiteralPath $env:USERPROFILE -Directory -Filter ".claude-compte*" | ForEach-Object { $_.FullName })
foreach ($d in $dirs) {
  $f = Join-Path $d "settings.json"
  if (-not (Test-Path -LiteralPath $f)) { continue }
  $raw = Get-Content -LiteralPath $f -Raw
  if ($raw.Contains("claude-statusline-seed.ps1")) { continue }
  Copy-Item -LiteralPath $f -Destination ($f + ".bak-seed") -Force
  $j = $raw | ConvertFrom-Json
  $entry = [PSCustomObject]@{ matcher = "startup"; hooks = @([PSCustomObject]@{ type = "command"; command = $hookCmd; timeout = 15 }) }
  if (-not $j.PSObject.Properties["hooks"]) { $j | Add-Member -NotePropertyName hooks -NotePropertyValue ([PSCustomObject]@{}) }
  if ($j.hooks.PSObject.Properties["SessionStart"]) { $j.hooks.SessionStart = @($j.hooks.SessionStart) + $entry }
  else { $j.hooks | Add-Member -NotePropertyName SessionStart -NotePropertyValue @($entry) }
  [IO.File]::WriteAllText($f, ($j | ConvertTo-Json -Depth 30), (New-Object Text.UTF8Encoding($false)))
  Write-Host ("rafraichissement des quotas de la barre d'etat actif dans " + $f)
}
Write-Host "termine, lance clm"
