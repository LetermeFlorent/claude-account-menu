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
Write-Host "termine, lance clm"
