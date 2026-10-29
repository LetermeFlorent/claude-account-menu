$raceLab = Split-Path -Parent $PSScriptRoot
. (Join-Path $raceLab "race-helpers.ps1")
. (Join-Path $PSScriptRoot "race-trees.ps1")
. (Join-Path $PSScriptRoot "race-tally.ps1")
. Import-ClmModule claude-self-copy

$irRoot = Join-Path $script:Sandbox "install-race"
$irHome = Join-Path $irRoot "home"
$irTarget = Join-Path (Join-Path $irHome ".local") "bin"
$irGate = Join-Path $irRoot "gate"
$irTreeA = New-RaceTree (Join-Path $irRoot "tree-a") "A"
$irTreeB = New-RaceTree (Join-Path $irRoot "tree-b") "B"
New-Item -ItemType Directory -Path $irTarget, $irGate -Force | Out-Null
$null = Install-ClmFiles -Source $irTreeA -Target $irTarget -Version $script:RaceStampA

$irAppData = Join-Path $irHome "AppData"
$irEnv = @{ USERPROFILE = $irHome; HOME = $irHome; LOCALAPPDATA = (Join-Path $irAppData "Local"); APPDATA = (Join-Path $irAppData "Roaming"); CLAUDE_CONFIG_DIR = $null }
$irBase = @{ Bin = $bin; Lab = $raceLab; Dir = $irGate; Target = $irTarget }
$irInstall = @{ Id = "installer"; TreeA = $irTreeA; TreeB = $irTreeB; StampA = $script:RaceStampA; StampB = $script:RaceStampB; Rounds = 9 }
$irKids = @(Start-RaceChild (Join-Path $PSScriptRoot "installer-child.ps1") ($irBase + $irInstall) $irEnv)
foreach ($irId in @("usage", "prefetch", "sync")) { $irKids += Start-RaceChild (Join-Path $PSScriptRoot ($irId + "-child.ps1")) ($irBase + @{ Id = $irId }) $irEnv }
Open-RaceGate $irGate $irKids.Count
$irRuns = @(foreach ($k in $irKids) { Wait-RaceChild $k 90000 })

$irName = "installation pendant le chargement : "
Assert-Equal "" (Format-RaceFailures $irRuns) ($irName + "aucun processus en echec")
Assert-Equal "usage=0 prefetch=0 sync=0" (Read-RaceTally $irRuns "mixed") ($irName + "aucun melange")
Assert-Equal "" (Read-RaceErrors $irRuns) ($irName + "aucune erreur affichee")
Assert-Equal "usage=B prefetch=B sync=B" (Read-RaceTally $irRuns "last") ($irName + "chaque processus finit sur la nouvelle version")
Assert-True ((Get-RaceTotal $irRuns "clean") -ge 3) ($irName + "des chargements propres")
Assert-True (((Get-RaceTotal $irRuns "stopped") + (Get-RaceTotal $irRuns "mixed")) -gt 0) ($irName + "des chargements ont croise une installation")
Assert-True ((Get-RaceTotal $irRuns "switches") -gt 0) ($irName + "des chargements ont vu l'ancienne puis la nouvelle version")

$irExpected = @(Get-RaceFileList $irTreeB)
$irFound = @(Get-RaceFileList $irTarget)
$irActual = @($irFound | Where-Object { $_ -ne "clm.version" -and $_ -ne "clm.files" })
Assert-Equal ($irExpected -join " ") ($irActual -join " ") ($irName + "la cible garde exactement les fichiers de B")
$irDiff = @(foreach ($f in $irExpected) {
  $t = Join-Path $irTarget $f
  if (-not [IO.File]::Exists($t) -or [Convert]::ToBase64String([IO.File]::ReadAllBytes($t)) -cne [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $irTreeB $f)))) { $f }
})
Assert-Equal "" ($irDiff -join " ") ($irName + "chaque fichier installe est identique a B")
Assert-Equal "" (@($irFound -like "*.tmp") -join " ") ($irName + "aucun fichier temporaire laisse")
Assert-True (-not (Test-Path -LiteralPath (Join-Path $irTarget "clm.installing"))) ($irName + "marqueur d'installation retire")
$irStamp = ""
if (Test-Path -LiteralPath (Join-Path $irTarget "clm.version")) { $irStamp = [IO.File]::ReadAllText((Join-Path $irTarget "clm.version")).Trim() }
Assert-Equal $script:RaceStampB $irStamp ($irName + "clm.version porte la version B")
[string[]]$irManifest = @()
if (Test-Path -LiteralPath (Join-Path $irTarget "clm.files")) {
  $irManifest = @([IO.File]::ReadAllLines((Join-Path $irTarget "clm.files")) | ForEach-Object { $_.Trim().Replace("\", "/") } | Where-Object { $_ })
  [Array]::Sort($irManifest, [StringComparer]::Ordinal)
}
Assert-Equal ($irExpected -join " ") ($irManifest -join " ") ($irName + "clm.files liste exactement les fichiers de B")
