param([string]$Bin, [string]$Lab, [string]$Dir, [string]$Id)
$ErrorActionPreference = "Stop"
. (Join-Path $Lab "race-helpers.ps1")
. (Join-Path $Bin "claude-import.ps1")
. Import-ClmModule claude-usage, claude-menu-view, claude-update, claude-menu-loop, claude-menu-startup
$script:FakeUpdateMs = 1500

function Get-Accounts { return @(foreach ($l in @("a", "b", "c")) { [PSCustomObject]@{ Label = $l; Dir = (".claude-" + $l) } }) }
function Test-Network { return $true }
function Start-ClaudeUpdate {
  param([string]$Exe, $Acc)
  [IO.File]::WriteAllText((Join-Path $Dir ("run-" + $Id)), $Id)
  return @{ Clock = [Diagnostics.Stopwatch]::StartNew(); State = (New-UpdateState); Watch = $null; Outcome = $null }
}
function Step-ClaudeUpdate {
  param($Run)
  if ($Run.Clock.ElapsedMilliseconds -lt $script:FakeUpdateMs) { return $false }
  $Run.Outcome = New-Outcome "ok" (Get-ClmText "update.claude.upToDateVersion" @("2.1.300"))
  return $true
}

$su = New-Startup @("claude")
$state = @{ Sel = 0; Msg = @("", $script:Ink.Dim); Dirty = $false; Entries = @() }
$clock = [Diagnostics.Stopwatch]::StartNew()
Wait-RaceGate $Dir $Id
while ((Test-StepsLeft $su @()) -and $clock.ElapsedMilliseconds -lt 60000) {
  $null = Step-Startup $su $state $clock.Elapsed.TotalMilliseconds
  Start-Sleep -Milliseconds 50
}
$step = $su.Steps[0]
"result " + $Id + " " + $step.State + " " + $step.Kind + " " + $step.Text
"stamp " + ((Read-SharedText (Get-StatePath "claude-check.done")) -replace "^[0-9]+ [0-9]+ ", "")
