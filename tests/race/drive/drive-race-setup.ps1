param([string]$Bin, [string]$Dir)
. (Join-Path $PSScriptRoot "drive-race-load.ps1") $Bin $Dir

Save-Registry @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" })
Save-DriveConfig @{ refreshToken = "r"; pc = "PCA" }
Save-SyncKeys (Get-DriveRaceKeys)
$file = Join-Path $script:HomeDir $script:DriveRaceFileRel
New-Item -ItemType Directory -Path (Split-Path -Parent $file) -Force | Out-Null
[IO.File]::WriteAllText($file, $script:DriveRaceFileText)
[IO.File]::SetLastWriteTimeUtc($file, [DateTimeOffset]::FromUnixTimeSeconds(1700000000).UtcDateTime)
