$raceStarts = 1 + [int]("0" + $env:CLM_RACE_STARTS)
$env:CLM_RACE_STARTS = [string]$raceStarts
$raceId = $env:CLM_RACE_ID
$raceDir = $env:CLM_RACE_DIR
$raceBin = $env:CLM_RACE_BIN
if ($raceStarts -gt 3) { Write-Host ("loop " + $raceId); exit 4 }
$raceQuits = $args -contains "--updated"
$raceArgs = @($args) -join " "

$script:ClmOnce = New-Object 'System.Collections.Generic.HashSet[string]'
. (Join-Path $raceBin "claude-import.ps1")
. Import-ClmModule claude-state-migrate, claude-boot-bar
. Import-ClmModule claude-usage, claude-menu-view, claude-menu-save, claude-menu-restore, claude-menu-select,
  claude-menu-remove, claude-menu-rename, claude-menu-prefs, claude-statusline-seed, claude-update, claude-self-update,
  claude-sync, claude-menu-loop, claude-menu-startup, claude-drive-cli, claude-account-guard, claude-cli
. (Join-Path (Split-Path -Parent $PSScriptRoot) "race-helpers.ps1")

$raceMarker = "absent"
$raceMarkerFile = Join-Path $raceBin "clm-race-marker.ps1"
if (Test-Path -LiteralPath $raceMarkerFile) { . $raceMarkerFile; $raceMarker = $script:RaceMarker }
Write-Host ("start " + $raceId + " " + $script:ClmLoadedSha + " " + $raceMarker + " " + $raceArgs)

$script:RaceClock = $null
$script:RaceReads = 0
$script:RaceStuckMs = 30000
$script:RaceIdleReads = 10

function Enter-UiScreen { $script:UiOn = $true }
function Exit-UiScreen { $script:UiOn = $false }
function Hide-Screen {}
function Update-UiTick { param([double]$Now, [bool]$Busy = $false) return $false }
function Clear-ConsoleInput {}
function Start-MenuLoader { param($State, $Indices = $null) }
function Start-UsageLoader { throw "reseau interdit dans ce test" }
function Invoke-GitHubGet { throw "reseau interdit dans ce test" }
function Test-Network { return $true }
function Test-DriveConnected { return $false }
function Test-DriveAuto { return $false }
function Get-DriveLastSync { return [long]0 }
function Start-DriveJob { param($Job, [switch]$Hold) }
function Get-Accounts { return @(foreach ($l in @("a", "b")) { [PSCustomObject]@{ Label = $l; Dir = (".claude-" + $l) } }) }

function Show-Menu {
  param($State, [double]$Now)
  $State.Dirty = $false
  if ($null -ne $script:RaceClock) { return }
  Wait-RaceGate $raceDir $raceId
  $script:RaceClock = [Diagnostics.Stopwatch]::StartNew()
}

function Read-UiInput {
  if ($null -eq $script:RaceClock) { return $null }
  $script:RaceReads++
  if ($raceQuits -and $script:RaceReads -ge $script:RaceIdleReads) { $script:UiQuit = $true }
  elseif ($script:RaceClock.ElapsedMilliseconds -gt $script:RaceStuckMs) {
    Write-Host ("stuck " + $raceId)
    exit 1
  }
  return $null
}

$chosen = Invoke-AccountMenu $false $false $false
if ($null -ne $chosen) {
  Write-Host ("account " + $chosen.Label)
  exit 3
}
if ($script:ClmUpdated) {
  Write-Host "  clm mis a jour, redemarrage" -ForegroundColor DarkGray
  Restart-Clm $PSCommandPath (Get-WebRestartArgs $args)
}
Write-Host ("result " + $raceId + " " + $script:ClmLoadedSha + " " + $raceMarker + " " + $raceArgs)
exit 0
