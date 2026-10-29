param([string]$Bin, [string]$Lab, [string]$Gate, [string]$Id, [string]$Mode, [string]$LockPath)
$ErrorActionPreference = "Stop"
. (Join-Path $Lab "race-helpers.ps1")
. (Join-Path $Bin "claude-import.ps1")
. Import-ClmModule claude-usage-cache

function Stop-RaceNetwork { throw "reseau interdit pendant les tests" }
Set-Alias -Name Invoke-RestMethod -Value Stop-RaceNetwork
Set-Alias -Name Invoke-WebRequest -Value Stop-RaceNetwork

if ($Mode -eq "hold") {
  $fs = Enter-FileLock $LockPath 5000
  if ($null -eq $fs) { throw "verrou du cache deja pris" }
  [IO.File]::WriteAllText((Join-Path $Gate "held"), "x")
  Start-Sleep -Milliseconds 4000
  $fs.Dispose()
  return
}

Wait-RaceGate $Gate $Id
foreach ($n in 1..15) { Save-UsageEntry ($Id + "-" + $n) ([PSCustomObject]@{ Pct5 = $n; Reset5 = $null; Pct7 = 0; Reset7 = $null }) }
"result " + $Id
