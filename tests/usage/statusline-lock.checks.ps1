$raceLab = Join-Path (Split-Path -Parent $PSScriptRoot) "race"
. (Join-Path $raceLab "race-helpers.ps1")
. (Join-Path (Join-Path $raceLab "backup") "lock-holder-start.ps1")
. Import-ClmModule claude-machine-lock
function Get-AccountUsage {
  param($Acc, [switch]$NoRefresh)
  return [PSCustomObject]@{ Error = $null; Pct5 = 42; Reset5 = "2030-01-01T00:00:00Z"; Pct7 = 7; Reset7 = "2030-01-03T00:00:00Z"; Age = 0 }
}
$lockState = Get-StatusStatePath
$lockAcc = [PSCustomObject]@{ Label = "compte1"; Dir = ".claude" }
$lockUtf8 = New-Object Text.UTF8Encoding($false)
New-Item -ItemType Directory -Force -Path (Split-Path $lockState) | Out-Null
[IO.File]::WriteAllText($lockState, "theme dark`n", $lockUtf8)

$lockWait = $script:StatusLockWaitMs
$script:StatusLockWaitMs = 300
$lockHeld = Open-MachineLock "statusline"
$lockErr = $null
try { Update-StatusState $lockAcc } catch { $lockErr = $_.Exception.Message }
Close-MachineLock $lockHeld
$script:StatusLockWaitMs = $lockWait
Assert-Null $lockErr "etat de la barre tenu trop longtemps par un autre clm : abandon sans erreur"
Assert-Equal "theme dark`n" ([IO.File]::ReadAllText($lockState)) "etat de la barre tenu trop longtemps par un autre clm : fichier laisse tel quel"
Assert-True ([IO.File]::Exists((Join-Path (Split-Path $lockState) ("state.clm-" + $PID + ".changes")))) "etat de la barre tenu trop longtemps par un autre clm : nos valeurs en fichier de changements"

$lockOther = "theme dark`nq5_at@claude-compte3 77`n"
$script:StatusLockWaitMs = 5000
$lockHolder = Start-LockHolder "statusline" 1000 $lockState $lockOther
Update-StatusState $lockAcc
$null = Wait-RaceChild $lockHolder
$script:StatusLockWaitMs = $lockWait
$lockLines = @([IO.File]::ReadAllText($lockState).TrimEnd("`n").Split("`n"))
Assert-True ($lockLines -contains "q5_at@claude-compte3 77") "etat de la barre ecrit par un autre clm pendant l'attente : ses lignes gardees"
Assert-True ($lockLines -contains "q5_pct@claude 42") "etat de la barre ecrit par un autre clm pendant l'attente : nos lignes ajoutees"
Assert-Equal 0 @(Get-ChildItem -LiteralPath (Split-Path $lockState) -Filter "*.tmp").Count "etat de la barre : aucun fichier temporaire laisse"

. (Join-Path $bin "claude-usage.ps1")
