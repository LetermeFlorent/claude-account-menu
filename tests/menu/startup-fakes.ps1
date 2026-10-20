. (Join-Path $bin "claude-menu-loop.ps1")
. (Join-Path $bin "claude-menu-startup.ps1")

$startupMocked = @("Start-UsageLoader", "Start-ClaudeUpdate", "Step-ClaudeUpdate", "Get-Accounts", "Test-ClmInstalledHere", "Test-DriveConnected", "Test-DriveAuto", "Get-DriveLastSync", "Start-DriveJob", "New-ClmCheck", "Start-MenuLoader")
$startupKept = @{}
foreach ($n in $startupMocked) { $f = Get-Item ("function:" + $n) -ErrorAction SilentlyContinue; if ($f) { $startupKept[$n] = $f.ScriptBlock } }

function Restore-StartupFakes {
  foreach ($n in $startupMocked) {
    if ($startupKept[$n]) { Set-Item -Path ("function:script:" + $n) -Value $startupKept[$n] }
    else { Remove-Item -Path ("function:script:" + $n) -ErrorAction SilentlyContinue }
  }
  $script:DriveJob = $null
  $script:Startup = $null
  $script:MenuState = $null
  $script:ClmCheck = $null
  $script:ClmUpdated = $false
  $script:ClmChecked = $false
  $script:MenuUpdated = $false
}

function New-FakeWork {
  param($Item)
  $q = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
  if ($null -ne $Item) { $q.Enqueue($Item) }
  return @{ Ps = $null; Ctl = @{ Done = $false; Error = $null }; Queue = $q }
}

function New-StartupCase {
  param([string[]]$Names)
  $script:Su = New-Startup $Names
  $script:St = @{ Sel = 0; Msg = @("", $script:Ink.Dim); Dirty = $false; Entries = @(foreach ($l in @("a", "b", "c")) { @{ Acc = [PSCustomObject]@{ Label = $l } } }) }
  $script:T = 1000.0
  $script:Loads = @()
  $script:ClaudeStarts = 0
  $script:DriveStarts = 0
  $script:DriveJob = New-DriveJob $true 0
  $script:ClmUpdated = $false
}

function Invoke-StartupTicks {
  param([int]$Count = 1)
  $changed = $false
  for ($i = 0; $i -lt $Count; $i++) { $script:T += 300; if (Step-Startup $script:Su $script:St $script:T) { $changed = $true } }
  return $changed
}

function Get-StepList {
  param([string]$Field)
  return (@($script:Su.Steps | ForEach-Object { "" + $_[$Field] }) -join "|")
}

function Send-StartupAct {
  param([string]$Name, [int]$Index = -1)
  return Get-StartupGate $script:Su @{ Name = $Name; Index = $Index } $script:St
}

function Get-Accounts { return @(foreach ($l in @("a", "b", "c")) { [PSCustomObject]@{ Label = $l; Dir = (".claude-" + $l) } }) }
function Start-UsageLoader {
  param($Accounts, [string]$Source, [string]$Reader)
  $script:Loads += $Reader
  $res = @(0, $script:FakeLatest, $script:FakeFindError)
  if ($Reader -ne "Find-ClmUpdate") { $script:InstallItem = @($Accounts)[0]; $res = @(0, $null, $script:FakeInstallError) }
  $script:Work = New-FakeWork $res
  return $script:Work
}
function Start-ClaudeUpdate { param([string]$Exe, $Acc) $script:ClaudeStarts++; return @{ Left = 2; State = (New-UpdateState); Watch = $null; Outcome = $null } }
function Step-ClaudeUpdate {
  param($Run)
  $Run.Left = $Run.Left - 1
  if ($Run.Left -gt 0) { return $false }
  $Run.Outcome = New-Outcome "ok" "Claude Code a jour (2.1.292)"
  return $true
}
function Start-DriveJob { param($Job) $script:DriveStarts++; $Job.Ctl = @{ Stop = $false; Progress = "" }; $Job.Loader = @{ Ctl = @{ Done = $false } } }
function Test-ClmInstalledHere { return $script:FakeInstalled }
function Test-DriveConnected { return $true }
function Test-DriveAuto { return $script:FakeAuto }
function Get-DriveLastSync { return [long]0 }
function New-ClmCheck { return @{ Loader = $null; NextAt = $null; Installed = $null; Latest = $null } }
function Start-MenuLoader { param($State) $script:MenuLoads++ }

$script:FakeLatest = $null
$script:FakeFindError = $null
$script:FakeInstallError = $null
$script:FakeInstalled = $true
$script:FakeAuto = $true
$script:FakeV62 = [PSCustomObject]@{ Sha = ("c" * 40); Time = 5; Number = 62 }
