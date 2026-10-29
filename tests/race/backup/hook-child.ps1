param([string]$Bin, [string]$Lab, [string]$Dir, [string]$Id, [string]$Account, [int]$Rounds)
$ErrorActionPreference = "Stop"
. (Join-Path $Lab "race-helpers.ps1")
. (Join-Path $Bin "claude-import.ps1")
. (Join-Path $Bin "claude-statusline-seed.ps1")

function Get-AccountUsage {
  param($Acc, [switch]$NoRefresh)
  return [PSCustomObject]@{ Error = $null; Pct5 = 42; Reset5 = "2030-01-01T00:00:00Z"; Pct7 = 7; Reset7 = "2030-01-03T00:00:00Z"; Age = 0 }
}

$script:WriteOriginal = ${function:Write-TextFileAtomic}
function Write-TextFileAtomic {
  param([string]$Path, [string]$Text, [switch]$Private, [switch]$Bom)
  Start-Sleep -Milliseconds 150
  & $script:WriteOriginal @PSBoundParameters
}

Wait-RaceGate $Dir $Id
foreach ($n in 1..$Rounds) { Update-StatusState ([PSCustomObject]@{ Label = $Id; Dir = $Account }) }
"result " + $Id + " done"
