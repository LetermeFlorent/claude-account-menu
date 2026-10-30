$itestSelf = $PSCommandPath
$itestId = $env:CLM_ITEST_ID
$itestMode = $env:CLM_ITEST_MODE
$itestStarts = 1 + [int]("0" + $env:CLM_ITEST_STARTS)
$env:CLM_ITEST_STARTS = [string]$itestStarts
if ($itestStarts -gt 3) { [Console]::Out.WriteLine("loop " + $itestId); exit 4 }
$itestArgs = @($args)
$itestMenu = Join-Path (Join-Path (Join-Path $env:HOME ".local") "bin") "claude-menu.ps1"
$itestSeed = Join-Path $PSScriptRoot "integration-fakes.ps1"
$itestSeeded = New-Object 'System.Collections.Generic.HashSet[guid]'
$itestClock = [Diagnostics.Stopwatch]::StartNew()
$itestStuckMs = 50000
$itestShown = $false
$itestPressed = ""
. $itestSeed
[Console]::Out.WriteLine("start " + $itestId + " " + $itestStarts + " " + ($itestArgs -join " "))

function Test-ItestFlag {
  param([string]$Name)
  return [IO.File]::Exists((Join-Path $env:CLM_ITEST_LOG $Name))
}

function Start-ItestLoader {
  param($Accounts, [string]$Source = "", [string]$Reader = "Get-AccountUsage", [switch]$Hold, $Runspace = $null)
  if (-not $Source) { $Source = Join-Path (Split-Path -Parent $itestMenu) "claude-usage.ps1" }
  if ($null -eq $Runspace) { $Runspace = [RunspaceFactory]::CreateRunspace(); $Runspace.Open() }
  if ($itestSeeded.Add($Runspace.InstanceId)) {
    $ps = [PowerShell]::Create()
    $ps.Runspace = $Runspace
    [void]$ps.AddScript('param($Seed) . $Seed').AddArgument($itestSeed)
    [void]$ps.Invoke()
    $ps.Dispose()
  }
  return & ${function:Start-UsageLoader} $Accounts $Source $Reader -Hold:$Hold -Runspace $Runspace
}

function Restart-ItestClm {
  param([string]$Script, [string[]]$Argv)
  & ${function:Restart-Clm} $itestSelf $Argv
}

function Invoke-ItestReload {
  param([string]$Script, [object[]]$Argv)
  & ${function:Invoke-ClmReload} $itestSelf $Argv
}

function Test-ItestSettled {
  $su = $script:Startup
  if ($null -ne $su -and ($null -ne $su.Exit -or (Test-StepsLeft $su @()))) { return $false }
  $st = $script:MenuState
  if ($null -eq $st -or -not $st.Opened) { return $false }
  if (@($st.Entries | Where-Object { $_.Pending }).Count -gt 0) { return $false }
  return -not (Test-DriveJobRunning $script:DriveJob)
}

function Get-ItestKey {
  if ($itestMode -eq "session") { return "1" }
  if ($itestMode -eq "quit" -or (Test-ItestFlag "quit-all")) { return "q" }
  if ($itestMode -ne "update") { return "" }
  if (Test-ClmUpdateReady) { return "u" }
  if ((Test-ItestFlag "update-now") -and $null -eq $script:ClmCheck.Loader -and $script:ClmCheck.NextAt -gt 0) { $script:ClmCheck.NextAt = 0 }
  return ""
}

function Read-ItestKey {
  if ($itestClock.ElapsedMilliseconds -gt $itestStuckMs) { [Console]::Out.WriteLine("stuck " + $itestId); exit 1 }
  if (-not (Test-ItestSettled)) { return $null }
  if (-not $script:itestShown) {
    $script:itestShown = $true
    [Console]::Out.WriteLine("menu " + $itestId + " " + $script:ClmLoadedSha + " " + ($itestArgs -join " "))
    [IO.File]::WriteAllText((Join-Path $env:CLM_ITEST_LOG ("menu-" + $itestStarts + "-" + $itestId)), $script:ClmLoadedSha)
  }
  $key = Get-ItestKey
  if (-not $key -or $script:itestPressed -eq $key) { return $null }
  $script:itestPressed = $key
  [Console]::Out.WriteLine("key " + $itestId + " " + $key)
  return New-KeyInfo $key
}

function Enable-ItestMouse {}
function Test-ItestRich { return $true }

$itestHooks = @{ "Start-UsageLoader" = "Start-ItestLoader"; "Restart-Clm" = "Restart-ItestClm"; "Invoke-ClmReload" = "Invoke-ItestReload"; "Read-UiKey" = "Read-ItestKey"; "Enable-UiMouse" = "Enable-ItestMouse"; "Test-RichTerminal" = "Test-ItestRich" }
foreach ($itestName in $itestHooks.Keys) { Set-Alias -Name $itestName -Value $itestHooks[$itestName] -Scope Global -Force }
if ($itestStarts -eq 1) {
  . (Join-Path (Split-Path -Parent $PSScriptRoot) "race-helpers.ps1")
  Wait-RaceGate $env:CLM_ITEST_GATE $itestId
}
. $itestMenu @itestArgs
