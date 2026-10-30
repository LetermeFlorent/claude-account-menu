. (Join-Path (Split-Path -Parent $PSScriptRoot) "race-helpers.ps1")

$holdChild = @'
param([string]$Bin, [string]$Dir)
$ErrorActionPreference = "Stop"
. (Join-Path $Bin "claude-import.ps1")
. Import-ClmModule claude-machine-lock
$lock = Open-MachineLock "race-hold"
if ($null -eq $lock) { throw "verrou deja pris" }
[IO.File]::WriteAllText((Join-Path $Dir "held"), "x")
Start-Sleep -Seconds 60
'@

$lockDir = Join-Path $script:Sandbox "race-lock"
New-Item -ItemType Directory -Path $lockDir -Force | Out-Null
$holder = Start-RaceChild (New-SandboxFile "race-lock-child.ps1" $holdChild) @{ Bin = $bin; Dir = $lockDir }
$heldAt = [DateTime]::UtcNow.AddMilliseconds($script:RaceReadyMs)
while (-not [IO.File]::Exists((Join-Path $lockDir "held")) -and -not $holder.Proc.HasExited -and [DateTime]::UtcNow -lt $heldAt) { Start-Sleep -Milliseconds $script:RacePollMs }
$busy = Open-MachineLock "race-hold"
Assert-Null $busy "verrou tenu par un autre clm : refuse"
Close-MachineLock $busy
try { $holder.Proc.Kill() } catch { Write-Verbose $_.Exception.Message }
$null = Wait-RaceChild $holder
$freed = Open-MachineLock "race-hold" 5000
Assert-True ($null -ne $freed) "clm arrete net avec le verrou : verrou repris"
Close-MachineLock $freed

$twice = Open-MachineLock "race-twice"
Assert-Null (Open-MachineLock "race-twice") "verrou deja pris dans ce clm : refuse"
Close-MachineLock $twice
$twice = Open-MachineLock "race-twice"
Assert-True ($null -ne $twice) "verrou rendu : repris"
Close-MachineLock $twice

Write-MachineStamp "race-stamp" "abc def"
Assert-Equal "abc def" (Read-MachineStamp "race-stamp" 60000) "trace d'une operation finie : relue"
Start-Sleep -Milliseconds 30
Assert-Null (Read-MachineStamp "race-stamp" 10) "trace trop ancienne : ignoree"
[IO.File]::WriteAllText((Get-StatePath "race-stamp.done"), "pas une trace")
Assert-Null (Read-MachineStamp "race-stamp" 60000) "trace illisible : ignoree"
Assert-Null (Read-MachineStamp "race-absent" 60000) "pas de trace : rien"
