$script:DriveWatchEvents = @("Changed", "Created", "Deleted", "Renamed", "Error")
$script:DriveWatchPrefix = "clm-watch-"
$script:DriveWatchBufferBytes = 65536
$script:DriveWatchCredName = ".credentials.json"

function New-WatchFsItem {
  param([string]$Path, [bool]$Deep, [string]$Id)
  $w = New-Object IO.FileSystemWatcher $Path
  $w.IncludeSubdirectories = $Deep
  $w.NotifyFilter = [IO.NotifyFilters]"FileName, DirectoryName, LastWrite, Size"
  $w.InternalBufferSize = $script:DriveWatchBufferBytes
  foreach ($e in $script:DriveWatchEvents) { $null = Register-ObjectEvent -InputObject $w -EventName $e -SourceIdentifier ($script:DriveWatchPrefix + $Id + "-" + $e) }
  $w.EnableRaisingEvents = $true
  return $w
}

function New-WatchFsContext {
  param([string]$Root, $Roots, $Patterns)
  return @{ Root = $Root; Roots = @($Roots); Rx = (Get-ExcludeRegex $Patterns); Items = @(); Blind = $false; Key = ($Roots -join "|") }
}

function Start-WatchFs {
  param($Ctx)
  $items = New-Object 'System.Collections.Generic.List[object]'
  try {
    $items.Add((New-WatchFsItem $Ctx.Root $false "home"))
    foreach ($r in $Ctx.Roots) {
      $full = Join-Path $Ctx.Root $r
      if ([IO.Directory]::Exists($full)) { $items.Add((New-WatchFsItem $full $true ("" + $items.Count))) }
    }
  } catch { $Ctx.Blind = $true }
  $Ctx.Items = $items.ToArray()
}

function Stop-WatchFs {
  param($Ctx)
  if ($null -eq $Ctx) { return }
  foreach ($w in $Ctx.Items) { $w.EnableRaisingEvents = $false; $w.Dispose() }
  $Ctx.Items = @()
  Get-EventSubscriber | Where-Object { $_.SourceIdentifier.StartsWith($script:DriveWatchPrefix) } | Unregister-Event
  Get-Event | Where-Object { $_.SourceIdentifier.StartsWith($script:DriveWatchPrefix) } | Remove-Event
}

function Test-WatchPathRelevant {
  param([string]$Full, $Ctx)
  if (-not $Full -or $Full.Length -le $Ctx.Root.Length) { return $false }
  $rel = $Full.Substring($Ctx.Root.Length).TrimStart($script:PathSeps).Replace("\", "/")
  if ($Ctx.Roots -notcontains $rel.Split("/")[0]) { return $false }
  $name = [IO.Path]::GetFileName($rel)
  if ($name -eq $script:DriveHeldName) { return $false }
  if ($name -eq $script:DriveWatchCredName) { return $true }
  return -not $Ctx.Rx.IsMatch($rel)
}

function Test-WatchEventRelevant {
  param($Info, $Ctx)
  if ($Info -is [IO.ErrorEventArgs]) { return $true }
  if ($Info -is [IO.RenamedEventArgs] -and (Test-WatchPathRelevant $Info.OldFullPath $Ctx)) { return $true }
  if ($Info.ChangeType -eq [IO.WatcherChangeTypes]::Changed -and [IO.Directory]::Exists($Info.FullPath)) { return $false }
  return Test-WatchPathRelevant $Info.FullPath $Ctx
}

function Receive-WatchEvents {
  param($Ctx)
  $hit = $false
  foreach ($e in @(Get-Event -ErrorAction SilentlyContinue)) {
    Remove-Event -EventIdentifier $e.EventIdentifier -ErrorAction SilentlyContinue
    if ($hit -or -not ("" + $e.SourceIdentifier).StartsWith($script:DriveWatchPrefix)) { continue }
    $hit = Test-WatchEventRelevant $e.SourceEventArgs $Ctx
  }
  return $hit
}
