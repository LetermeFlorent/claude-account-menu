$script:DriveParallel = 4
$script:DrivePrefetchMin = 8
$script:DrivePrefetchPollMs = 20
$script:DrivePrefetchStopMs = 5000
$script:DrivePrefetchSource = Join-Path $PSScriptRoot "claude-drive-actions.ps1"

$script:PrefetchWorkerScript = {
  param([string]$Source, $Work, $Results, $Ctl)
  . $Source
  $item = $null
  while (-not $Ctl.Stop -and $Work.TryDequeue([ref]$item)) {
    if ($Ctl.Deadline -gt 0 -and [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() -ge $Ctl.Deadline) { break }
    try {
      if ($item.Kind -eq "download") {
        $null = [IO.Directory]::CreateDirectory((Split-Path -Parent $item.Tmp))
        Save-DriveMedia $item.Id $item.Tmp
        $out = @{ Ok = $true }
      } else {
        $out = @{ Ok = $true; Sent = (Send-DriveContent $item.Folder $item.Rel (Get-SyncBytes $item.Rel $item.Full) $item.Props $item.Id) }
      }
    } catch {
      if ($item.Kind -eq "download") { Remove-DriveTemp $item.Tmp }
      $out = @{ Ok = $false; Error = $_.Exception.Message }
    }
    $Results[$item.Rel] = $out
  }
}

function Get-UploadProps {
  param($Ctx, [string]$Rel)
  return @{ m = ("" + $Ctx.Local[$Rel].M); pc = $Ctx.Pc }
}

function Get-RemoteId {
  param($Ctx, [string]$Rel)
  $R = $Ctx.Remote[$Rel]
  if ($null -eq $R) { return "" }
  return [string]$R.Id
}

function Test-Prefetchable {
  param($Ctx, $Action)
  if ($Action.Kind -eq "download") { return $true }
  return $Action.Kind -eq "upload" -and [long]$Ctx.Local[$Action.Path].Size -le $script:DriveSimpleMax
}

function New-PrefetchItem {
  param($Ctx, $Action)
  $rel = $Action.Path
  if ($Action.Kind -eq "download") {
    return @{ Kind = "download"; Rel = $rel; Id = (Get-RemoteId $Ctx $rel); Tmp = (Get-SyncLocalPath $rel) + "." + [guid]::NewGuid().ToString("N") + ".tmp" }
  }
  return @{ Kind = "upload"; Rel = $rel; Full = $Ctx.Local[$rel].Full; Folder = $Ctx.Folder; Props = (Get-UploadProps $Ctx $rel); Id = (Get-RemoteId $Ctx $rel) }
}

function Set-DriveConnectionLimit {
  $n = $script:DriveParallel * 2
  if ([Net.ServicePointManager]::DefaultConnectionLimit -lt $n) { [Net.ServicePointManager]::DefaultConnectionLimit = $n }
  $sp = [Net.ServicePointManager]::FindServicePoint([Uri]$script:DriveApi)
  if ($sp.ConnectionLimit -lt $n) { $sp.ConnectionLimit = $n }
}

function Start-PrefetchWorker {
  param($Pre)
  $ps = [PowerShell]::Create()
  [void]$ps.AddScript($script:PrefetchWorkerScript).AddArgument($script:DrivePrefetchSource).AddArgument($Pre.Work).AddArgument($Pre.Results).AddArgument($Pre.Ctl)
  return @{ Ps = $ps; Handle = $ps.BeginInvoke() }
}

function Start-TransferPrefetch {
  param($Ctx, $Plan, [long]$DeadlineMs)
  $items = @(foreach ($a in $Plan) { if (Test-Prefetchable $Ctx $a) { New-PrefetchItem $Ctx $a } })
  if ($script:DriveParallel -le 1 -or $items.Count -lt $script:DrivePrefetchMin) { return $null }
  Set-DriveConnectionLimit
  $pre = @{ Work = (New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'); Planned = (New-PathMap); Workers = @() }
  $pre.Results = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([StringComparer]::Ordinal)
  $pre.Ctl = [hashtable]::Synchronized(@{ Stop = $false; Deadline = $DeadlineMs })
  foreach ($i in $items) { $pre.Work.Enqueue($i); $pre.Planned[$i.Rel] = $i }
  $pre.Workers = @(for ($n = 0; $n -lt $script:DriveParallel; $n++) { Start-PrefetchWorker $pre })
  return $pre
}

function Test-PrefetchRunning {
  param($Pre)
  foreach ($w in $Pre.Workers) { if (-not $w.Handle.IsCompleted) { return $true } }
  return $false
}

function Wait-PrefetchResult {
  param($Pre, [string]$Rel)
  if ($null -eq $Pre -or -not $Pre.Planned.ContainsKey($Rel)) { return $null }
  $out = $null
  while ($true) {
    $running = Test-PrefetchRunning $Pre
    if ($Pre.Results.TryGetValue($Rel, [ref]$out)) { break }
    if (-not $running) { return $null }
    Start-Sleep -Milliseconds $script:DrivePrefetchPollMs
  }
  if (-not $out.Ok) { return $null }
  return $out
}

function Get-PrefetchedTemp {
  param($Pre, [string]$Rel)
  $out = Wait-PrefetchResult $Pre $Rel
  if ($null -eq $out) { return "" }
  $tmp = $Pre.Planned[$Rel].Tmp
  if (-not [IO.File]::Exists($tmp)) { return "" }
  return $tmp
}

function Get-PrefetchedUpload {
  param($Pre, [string]$Rel)
  $out = Wait-PrefetchResult $Pre $Rel
  if ($null -eq $out) { return $null }
  return $out.Sent
}

function Stop-TransferPrefetch {
  param($Pre)
  if ($null -eq $Pre) { return }
  $Pre.Ctl.Stop = $true
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ((Test-PrefetchRunning $Pre) -and $sw.ElapsedMilliseconds -lt $script:DrivePrefetchStopMs) { Start-Sleep -Milliseconds $script:DrivePrefetchPollMs }
  foreach ($w in $Pre.Workers) {
    try { if (-not $w.Handle.IsCompleted) { $w.Ps.Stop() } else { [void]$w.Ps.EndInvoke($w.Handle) } } catch {}
    $w.Ps.Dispose()
  }
  foreach ($i in $Pre.Planned.Values) { if ($i.Kind -eq "download") { Remove-DriveTemp $i.Tmp } }
}
