$script:LoaderScript = Add-ClmGuardedLoad @'
param($Source, $Reader, $Accounts, $Ctl, $Queue)
$ProgressPreference = "SilentlyContinue"
try {
  <ClmGuardedLoad>
  if ($clmReplaced) { $Ctl.Replaced = $true; return }
  $Ctl.Go.Wait()
  for ($i = 0; $i -lt $Accounts.Count; $i++) {
    if ($Ctl.Stop) { break }
    $Ctl.Current = $i
    try { $Queue.Enqueue(@($i, (& $Reader $Accounts[$i]), $null)) }
    catch { $Queue.Enqueue(@($i, $null, $_.Exception.Message)) }
  }
} catch { $Ctl.Error = $_.Exception.Message }
finally { $Ctl.Current = -1; $Ctl.Done = $true }
'@

$script:UsageRunspace = $null
$script:LeftRunspaces = @()

function Close-LeftRunspaces {
  $keep = @()
  foreach ($old in $script:LeftRunspaces) {
    if ($old.RunspaceAvailability -eq "Busy") { $keep += $old; continue }
    $old.Dispose()
  }
  $script:LeftRunspaces = $keep
}

function Get-UsageRunspace {
  Close-LeftRunspaces
  $rs = $script:UsageRunspace
  if ($null -ne $rs -and $rs.RunspaceStateInfo.State -eq "Opened" -and $rs.RunspaceAvailability -eq "Available") { return $rs }
  if ($null -ne $rs) { $script:LeftRunspaces += $rs }
  $rs = [RunspaceFactory]::CreateRunspace()
  $rs.Open()
  $script:UsageRunspace = $rs
  return $rs
}

function Start-UsageLoader {
  param($Accounts, [string]$Source = (Join-Path $PSScriptRoot "claude-usage.ps1"), [string]$Reader = "Get-AccountUsage", [switch]$Hold, $Runspace = $null)
  $go = New-Object Threading.ManualResetEventSlim((-not $Hold))
  $ctl = [hashtable]::Synchronized(@{ Stop = $false; Done = $false; Current = -1; Error = $null; Go = $go })
  $queue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
  $ps = [PowerShell]::Create()
  if ($null -ne $Runspace) { $ps.Runspace = $Runspace }
  [void]$ps.AddScript($script:LoaderScript).AddArgument($Source).AddArgument($Reader).AddArgument(@($Accounts)).AddArgument($ctl).AddArgument($queue)
  $handle = $ps.BeginInvoke()
  return @{ Ps = $ps; Handle = $handle; Ctl = $ctl; Queue = $queue }
}

function Receive-UsageResults {
  param($Loader)
  $out = New-Object 'System.Collections.Generic.List[object]'
  $item = $null
  while ($Loader.Queue.TryDequeue([ref]$item)) { $out.Add($item) }
  return ,$out.ToArray()
}

function Resume-UsageLoader {
  param($Loader)
  if ($null -ne $Loader -and $null -ne $Loader.Ctl.Go) { $Loader.Ctl.Go.Set() }
}

function Test-UsageLoaderHeld {
  param($Loader)
  return $null -ne $Loader -and $null -ne $Loader.Ctl.Go -and -not $Loader.Ctl.Go.IsSet
}

function Close-UsageLoader {
  param($Loader)
  if ($null -eq $Loader.Ps -or -not $Loader.Ctl.Done) { return }
  try { [void]$Loader.Ps.EndInvoke($Loader.Handle) } catch { Write-Verbose $_.Exception.Message }
  $Loader.Ps.Dispose()
  $Loader.Ps = $null
}

function Stop-UsageLoader {
  param($Loader, [int]$TimeoutMs = 30000, [scriptblock]$OnWait = $null)
  if ($null -eq $Loader) { return }
  $Loader.Ctl.Stop = $true
  Resume-UsageLoader $Loader
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while (-not $Loader.Ctl.Done -and $sw.ElapsedMilliseconds -lt $TimeoutMs) {
    if ($null -ne $OnWait) { & $OnWait $sw.ElapsedMilliseconds }
    Start-Sleep -Milliseconds 50
  }
  Close-UsageLoader $Loader
}
