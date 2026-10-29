param([string]$Bin, [string]$Lab, [string]$Dir, [string]$Id, [string]$Target)
$ErrorActionPreference = "Stop"
. (Join-Path $Lab "race-helpers.ps1")
. (Join-Path $PSScriptRoot "race-tally.ps1")
. (Join-Path $Bin "claude-import.ps1")
. Import-ClmModule claude-drive-prefetch
$entry = Join-Path $Target "race-entry.ps1"

function Invoke-PrefetchRun {
  $work = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
  $work.Enqueue(@{ Kind = "upload"; Rel = "race.txt"; Full = (Join-Path $Target "race.txt"); Folder = "race-folder"; Props = @{}; Id = "" })
  $results = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([StringComparer]::Ordinal)
  $ctl = [hashtable]::Synchronized(@{ Stop = $false; Deadline = 0; Keys = $null })
  $errors = @()
  $ps = [PowerShell]::Create()
  try {
    [void]$ps.AddScript($script:PrefetchWorkerScript).AddArgument($entry).AddArgument($work).AddArgument($results).AddArgument($ctl)
    $null = $ps.Invoke()
  } catch { $errors += $_.Exception.GetBaseException().Message }
  $errors += @($ps.Streams.Error | ForEach-Object { "" + $_ })
  $ps.Dispose()
  $out = $null
  $seen = ""
  if ($results.TryGetValue("race.txt", [ref]$out)) {
    if ($out.Ok) { $seen = "" + $out.Sent } else { $errors += ("" + $out.Error) }
  }
  $stopped = $results.Count -eq 0 -and $work.Count -eq 1
  return @{ Seen = $seen; Stopped = $stopped; Error = ($errors -join "; ") }
}

Wait-RaceGate $Dir $Id
Invoke-RaceLoop $Dir $Id { Invoke-PrefetchRun }
