. (Join-Path (Split-Path -Parent $PSScriptRoot) "race-helpers.ps1")
. (Join-Path $PSScriptRoot "drive-race-store.ps1")
. (Join-Path $PSScriptRoot "drive-race-report.ps1")

$driveRoot = Join-Path $script:Sandbox "drive-race"
$driveHome = Join-Path $driveRoot "home"
$driveDir = Join-Path $driveRoot "race"
New-Item -ItemType Directory -Path $driveHome, $driveDir -Force | Out-Null
$driveEnv = @{ USERPROFILE = $driveHome; HOME = $driveHome; LOCALAPPDATA = (Join-Path $driveHome "AppData"); APPDATA = (Join-Path $driveHome "Roaming"); XDG_STATE_HOME = (Join-Path $driveHome "state"); XDG_CONFIG_HOME = (Join-Path $driveHome "config"); XDG_CACHE_HOME = (Join-Path $driveHome "cache"); CLAUDE_CONFIG_DIR = $null }
$driveSetup = Wait-RaceChild (Start-RaceChild (Join-Path $PSScriptRoot "drive-race-setup.ps1") @{ Bin = $bin; Dir = $driveDir } $driveEnv)
Assert-Equal "" (Format-RaceFailures @($driveSetup)) "course Drive : preparation sans erreur"

$driveIds = @("d1", "d2", "d3")
$driveParams = @(foreach ($n in $driveIds) { @{ Bin = $bin; Dir = $driveDir; Id = $n } })
$driveRuns = Invoke-Race (Join-Path $PSScriptRoot "drive-race-child.ps1") $driveParams $driveDir $driveEnv
$driveName = "trois synchros Drive en meme temps"
Assert-Equal "" (Format-RaceFailures $driveRuns) ($driveName + " : aucune erreur")

$driveKinds = @(for ($i = 0; $i -lt $driveIds.Count; $i++) { Get-DriveRaceKind $driveRuns[$i] $driveIds[$i] })
$driveBadOut = @(for ($i = 0; $i -lt $driveIds.Count; $i++) { if (-not $driveKinds[$i]) { $driveIds[$i] + " [" + $driveRuns[$i].Out + "]" } }) -join " | "
Assert-Equal "" $driveBadOut ($driveName + " : une seule ligne de resultat par clm")
$driveText = @($driveRuns | ForEach-Object { $_.Out + " " + $_.Err }) -join " "
$driveWords = @([regex]::Matches($driveText, "erreur|echec|en cours|impossible|ignoree|avertissement|warning", "IgnoreCase") | ForEach-Object { $_.Value }) -join ","
Assert-Equal "" $driveWords ($driveName + " : aucun message d'erreur ni d'avertissement")

$driveJson = @{}
$driveStatus = @(for ($i = 0; $i -lt $driveIds.Count; $i++) {
  $j = Read-DriveRaceJson (Join-Path $driveDir ("result-" + $driveIds[$i] + ".json"))
  if ($null -eq $j) { $driveIds[$i] + " sans resultat" }
  else { $driveJson[$driveIds[$i]] = $j; $driveIds[$i] + " " + $j.Ok + " [" + $j.Error + "] " + ((Get-DriveRaceFlagKind $j) -eq $driveKinds[$i]) }
}) -join "|"
Assert-Equal "d1 True [] True|d2 True [] True|d3 True [] True" $driveStatus ($driveName + " : chaque synchro reussit sans erreur, comme la ligne affichee")

$driveDone = @(for ($i = 0; $i -lt $driveIds.Count; $i++) { if ($driveKinds[$i] -eq "done") { $driveIds[$i] } })
$driveSkipped = @($driveKinds | Where-Object { $_ -eq "skipped" })
$drivePasses = Get-DriveRacePasses $driveDir
Assert-True ($driveDone.Count -ge 1) ($driveName + " : au moins un clm fait la synchro")
$driveRedone = ""
if ($driveSkipped.Count -eq 0) { $driveRedone = "aucun clm ne reprend la synchro faite : " + ($driveKinds -join ",") + ", " + $drivePasses.Count + " passages" }
Assert-Equal "" $driveRedone ($driveName + " : les clm en attente reprennent la synchro faite sans la refaire")
$drivePassIds = @($drivePasses | ForEach-Object { $_.Id } | Sort-Object -Unique) -join ","
Assert-Equal ($driveDone -join ",") $drivePassIds ($driveName + " : seuls les clm qui font la synchro la lancent")
Assert-Equal "" (Get-DriveRaceOverlaps $drivePasses) ($driveName + " : jamais deux synchros en meme temps")

$driveCfgPaths = @($driveJson.Values | ForEach-Object { [string]$_.Config } | Sort-Object -Unique)
$driveStatePaths = @($driveJson.Values | ForEach-Object { [string]$_.State } | Sort-Object -Unique)
$driveIsolated = $driveCfgPaths.Count -eq 1 -and $driveStatePaths.Count -eq 1 -and $driveCfgPaths[0].StartsWith($driveHome, "OrdinalIgnoreCase") -and $driveStatePaths[0].StartsWith($driveHome, "OrdinalIgnoreCase")
Assert-True $driveIsolated ($driveName + " : etat Drive ecrit dans le dossier isole")
$driveCfg = Read-DriveRaceJson ([string]($driveCfgPaths | Select-Object -First 1))
Assert-Equal "r" $driveCfg.refreshToken ($driveName + " : drive.json lisible, jeton garde")
Assert-True ([long]$driveCfg.lastSync -gt 0) ($driveName + " : drive.json garde l'heure de la synchro")
Assert-True ($null -ne (Read-DriveRaceJson ([string]($driveStatePaths | Select-Object -First 1)))) ($driveName + " : drive-state.json lisible")
Assert-Equal $script:DriveRaceFileText (Get-DriveRaceRemoteText (Join-Path $driveDir "drive") (Get-DriveRaceKeys)) ($driveName + " : fichier present une seule fois sur le Drive, contenu intact")
