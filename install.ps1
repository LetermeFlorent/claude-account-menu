$ErrorActionPreference = "Stop"
$src = Join-Path $PSScriptRoot "bin"
$dst = Join-Path $env:USERPROFILE ".local\bin"
. (Join-Path $src "claude-import.ps1")
. Import-ClmModule claude-self-copy
$version = ""
if ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot ".git"))) {
  $line = (& git -C $PSScriptRoot log -1 --format="%H %ct") + " " + (& git -C $PSScriptRoot rev-list --count HEAD)
  if ($LASTEXITCODE -eq 0) { $version = $line }
} elseif (Test-Path -LiteralPath (Join-Path $PSScriptRoot "clm.version")) {
  $version = [IO.File]::ReadAllText((Join-Path $PSScriptRoot "clm.version"))
}
Install-ClmFiles $src $dst $version @("clm")
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
& (Join-Path $PSScriptRoot "install-hook.ps1")
Write-Host "termine, lance clm"
