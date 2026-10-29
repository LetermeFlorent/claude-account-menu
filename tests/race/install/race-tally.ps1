$script:RaceLoopMs = 90000
$script:RaceLoopPauseMs = 20
$script:RaceSignalMs = 30000

function New-RaceTally {
  return @{ Clean = 0; Mixed = 0; Errors = 0; Stopped = 0; Switches = 0; Last = "-"; Notes = (New-Object 'System.Collections.Generic.List[string]') }
}

function Add-RaceOutcome {
  param($Tally, $Run)
  $seen = "" + $Run.Seen
  $err = ("" + $Run.Error) -replace "\s+", " "
  if ($err) {
    $Tally.Errors++
    if ($Tally.Notes.Count -lt 3 -and -not $Tally.Notes.Contains($err)) { $Tally.Notes.Add($err) }
  } elseif ($Run.Stopped) {
    $Tally.Stopped++
  } elseif ($seen.Contains(",")) {
    $Tally.Mixed++
  } elseif ($seen -ceq "A" -or $seen -ceq "B") {
    $Tally.Clean++
    if ($Tally.Last -ne "-" -and $Tally.Last -ne $seen) { $Tally.Switches++ }
    $Tally.Last = $seen
  } else {
    Add-RaceOutcome $Tally @{ Error = ("chargement sans resultat [" + $seen + "]") }
  }
}

function Set-RaceSignal {
  param([string]$Dir, [string]$Name)
  $p = Join-Path $Dir $Name
  if (-not [IO.File]::Exists($p)) { [IO.File]::WriteAllText($p, $Name) }
}

function Wait-RaceSignals {
  param([string]$Dir, [string]$Prefix, [int]$Count)
  $sw = [Diagnostics.Stopwatch]::StartNew()
  do {
    $found = @(Get-ChildItem -LiteralPath $Dir -Filter ($Prefix + "*")).Count
    if ($found -ge $Count -or $sw.ElapsedMilliseconds -gt $script:RaceSignalMs) { return $found }
    Start-Sleep -Milliseconds 10
  } while ($true)
}

function Invoke-RaceLoop {
  param([string]$Dir, [string]$Id, [scriptblock]$Run)
  $tally = New-RaceTally
  $sw = [Diagnostics.Stopwatch]::StartNew()
  do {
    $last = [IO.File]::Exists((Join-Path $Dir "installed")) -or $sw.ElapsedMilliseconds -gt $script:RaceLoopMs
    try { $outcome = @(& $Run)[-1] } catch { $outcome = @{ Error = $_.Exception.Message } }
    Add-RaceOutcome $tally $outcome
    if ($tally.Clean -gt 0) { Set-RaceSignal $Dir ("clean-" + $Id) }
    if ($tally.Stopped -gt 0) { Set-RaceSignal $Dir ("held-" + $Id) }
    Start-Sleep -Milliseconds $script:RaceLoopPauseMs
  } until ($last)
  foreach ($n in $tally.Notes) { "error " + $Id + " " + $n }
  "summary " + $Id + " clean=" + $tally.Clean + " mixed=" + $tally.Mixed + " errors=" + $tally.Errors + " stopped=" + $tally.Stopped + " switches=" + $tally.Switches + " last=" + $tally.Last
}

function Get-RaceLines {
  param($Runs, [string]$Prefix)
  return @(foreach ($r in $Runs) { @($r.Out -split "`r?`n" | Where-Object { $_.StartsWith($Prefix) }) })
}

function Read-RaceTally {
  param($Runs, [string]$Field)
  $parts = @(foreach ($line in (Get-RaceLines $Runs "summary ")) { if ($line -match ("^summary (\S+) .*\b" + $Field + "=(\S+)")) { $Matches[1] + "=" + $Matches[2] } })
  return ($parts -join " ")
}

function Get-RaceTotal {
  param($Runs, [string]$Field)
  $sum = 0
  foreach ($line in (Get-RaceLines $Runs "summary ")) { if ($line -match ("\b" + $Field + "=(\d+)")) { $sum += [int]$Matches[1] } }
  return $sum
}

function Read-RaceErrors {
  param($Runs)
  return ((Get-RaceLines $Runs "error ") -join " | ")
}
