param([string]$Bin, [string]$Lab, [string]$Dir, [string]$Id, [string]$Target, [string]$TreeA, [string]$TreeB, [string]$StampA, [string]$StampB, [int]$Rounds, [int]$Loaders)
$ErrorActionPreference = "Stop"
. (Join-Path $Lab "race-helpers.ps1")
. (Join-Path $PSScriptRoot "race-tally.ps1")
. (Join-Path $Bin "claude-import.ps1")
. Import-ClmModule claude-self-copy
$script:RaceCopy = ${function:Copy-ClmFile}
$script:RaceHeld = -1

function Copy-ClmFile {
  param([string]$From, [string]$To)
  if ($script:RaceHeld -lt 0) { $script:RaceHeld = Wait-RaceSignals $Dir "held-" $Loaders }
  & $script:RaceCopy $From $To
}

function Get-RoundStamp {
  param([string]$Stamp, [int]$Round, [int]$Last)
  if ($Round -eq $Last) { return $Stamp }
  $parts = $Stamp.Split(" ")
  return $parts[0] + " " + ([long]$parts[1] + $Round) + " " + (100 + $Round)
}

Wait-RaceGate $Dir $Id
$sw = [Diagnostics.Stopwatch]::StartNew()
$ready = Wait-RaceSignals $Dir "clean-" $Loaders
try {
  for ($n = 1; $n -le $Rounds; $n++) {
    if ($n % 2 -eq 1) { $src = $TreeB; $stamp = Get-RoundStamp $StampB $n $Rounds } else { $src = $TreeA; $stamp = Get-RoundStamp $StampA $n $Rounds }
    $null = Install-ClmFiles -Source $src -Target $Target -Version $stamp
    Start-Sleep -Milliseconds 200
  }
} finally {
  [IO.File]::WriteAllText((Join-Path $Dir "installed"), "x")
}
"summary " + $Id + " rounds=" + $Rounds + " ready=" + $ready + " held=" + $script:RaceHeld + " ms=" + $sw.ElapsedMilliseconds
