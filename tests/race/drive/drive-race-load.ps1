param([string]$Bin, [string]$Dir)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$script:SyncKeyStoreOs = "Linux"
. (Join-Path $Bin "claude-import.ps1")
. Import-ClmModule claude-drive-sync
. (Join-Path $PSScriptRoot "drive-race-fake.ps1")

function Stop-DriveRaceNetwork { throw "reseau interdit pendant les tests" }
Set-Alias -Name Invoke-WebRequest -Value Stop-DriveRaceNetwork
Set-Alias -Name Invoke-RestMethod -Value Stop-DriveRaceNetwork
function Test-ClmReplaced { return $false }

$script:SyncKeyStoreOs = "Linux"
$script:DriveParallel = 1
$script:DriveLockWaitMs = 20000
$script:DriveRaceStore = Join-Path $Dir "drive"
