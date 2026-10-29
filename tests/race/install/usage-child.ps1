param([string]$Bin, [string]$Lab, [string]$Dir, [string]$Id, [string]$Target)
$ErrorActionPreference = "Stop"
. (Join-Path $Lab "race-helpers.ps1")
. (Join-Path $PSScriptRoot "race-tally.ps1")
. (Join-Path $Bin "claude-import.ps1")
. Import-ClmModule claude-ui-loader
$entry = Join-Path $Target "race-entry.ps1"

function Invoke-UsageRun {
  $loader = Start-UsageLoader @("race") $entry "Get-RaceUsage"
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while (-not $loader.Ctl.Done -and $sw.ElapsedMilliseconds -lt 20000) { Start-Sleep -Milliseconds 5 }
  $items = Receive-UsageResults $loader
  $errors = @($loader.Ps.Streams.Error | ForEach-Object { "" + $_ })
  if ($loader.Ctl.Error) { $errors += ("" + $loader.Ctl.Error) }
  if (-not $loader.Ctl.Done) { $errors += "chargement bloque" }
  foreach ($i in $items) { if ($i[2]) { $errors += ("" + $i[2]) } }
  $stopped = $loader.Ctl.Replaced -eq $true
  if ($stopped -and $items.Count -gt 0) { $errors += "arret apres un resultat" }
  Close-UsageLoader $loader
  $seen = ""
  if ($items.Count -gt 0) { $seen = "" + $items[0][1] }
  return @{ Seen = $seen; Stopped = $stopped; Error = ($errors -join "; ") }
}

Wait-RaceGate $Dir $Id
Invoke-RaceLoop $Dir $Id { Invoke-UsageRun }
