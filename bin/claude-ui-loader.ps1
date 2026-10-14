$script:LoaderScript = @'
param($Source, $Reader, $Accounts, $Ctl, $Queue)
$ProgressPreference = "SilentlyContinue"
try {
  . $Source
  for ($i = 0; $i -lt $Accounts.Count; $i++) {
    if ($Ctl.Stop) { break }
    $Ctl.Current = $i
    try { $Queue.Enqueue(@($i, (& $Reader $Accounts[$i]), $null)) }
    catch { $Queue.Enqueue(@($i, $null, $_.Exception.Message)) }
  }
} catch { $Ctl.Error = $_.Exception.Message }
finally { $Ctl.Current = -1; $Ctl.Done = $true }
'@

function Start-UsageLoader {
  param($Accounts, [string]$Source = (Join-Path $PSScriptRoot "claude-usage.ps1"), [string]$Reader = "Get-CompteUsage")
  $ctl = [hashtable]::Synchronized(@{ Stop = $false; Done = $false; Current = -1; Error = $null })
  $queue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
  $ps = [PowerShell]::Create()
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

function Close-UsageLoader {
  param($Loader)
  if ($null -eq $Loader.Ps -or -not $Loader.Ctl.Done) { return }
  try { [void]$Loader.Ps.EndInvoke($Loader.Handle) } catch {}
  $Loader.Ps.Dispose()
  $Loader.Ps = $null
}

function Stop-UsageLoader {
  param($Loader, [int]$TimeoutMs = 30000, [scriptblock]$OnWait = $null)
  if ($null -eq $Loader) { return }
  $Loader.Ctl.Stop = $true
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while (-not $Loader.Ctl.Done -and $sw.ElapsedMilliseconds -lt $TimeoutMs) {
    if ($null -ne $OnWait) { & $OnWait $sw.ElapsedMilliseconds }
    Start-Sleep -Milliseconds 50
  }
  Close-UsageLoader $Loader
}
