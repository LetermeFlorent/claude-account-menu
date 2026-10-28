$ErrorActionPreference = "Stop"
$src = Join-Path $PSScriptRoot "bin"
$dst = Join-Path $env:USERPROFILE ".local\bin"
if (-not (Test-Path -LiteralPath $dst)) { New-Item -ItemType Directory -Path $dst | Out-Null }
Get-ChildItem -LiteralPath $src -File | Where-Object { $_.Extension -eq ".ps1" -or $_.Extension -eq ".cmd" } | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $dst -Force }
$webDst = Join-Path $dst "clm-web"
if (Test-Path -LiteralPath $webDst) { Remove-Item -LiteralPath $webDst -Recurse -Force }
Copy-Item -LiteralPath (Join-Path $src "clm-web") -Destination $webDst -Recurse
Write-Host ("scripts copies dans " + $dst)
$versionFile = Join-Path $dst "clm.version"
if (Test-Path -LiteralPath $versionFile) { Remove-Item -LiteralPath $versionFile -Force }
if ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot ".git"))) {
  $version = (& git -C $PSScriptRoot log -1 --format="%H %ct") + " " + (& git -C $PSScriptRoot rev-list --count HEAD)
  if ($LASTEXITCODE -eq 0 -and $version) { [IO.File]::WriteAllText($versionFile, $version + "`n", (New-Object Text.UTF8Encoding($false))) }
} elseif (Test-Path -LiteralPath (Join-Path $PSScriptRoot "clm.version")) {
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot "clm.version") -Destination $versionFile -Force
}

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
& (Join-Path $PSScriptRoot "install-hook.ps1")
Write-Host "termine, lance clm"
