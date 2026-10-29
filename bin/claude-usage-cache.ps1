. Import-ClmModule claude-file-io, claude-platform
$script:UsageCachePath = Get-UsageCachePath
$script:UsageCacheTtl = 180
$script:ForcedReadMaxAge = 30
$script:CooldownBaseSec = 60
$script:CooldownMaxSec = 600
$script:RetryAfterMaxSec = 3600
$script:UsageCacheLockMs = 3000

function Read-UsageCache {
  if (-not (Test-Path -LiteralPath $script:UsageCachePath)) { return @{} }
  try {
    $raw = Read-SharedText $script:UsageCachePath | ConvertFrom-Json
    $map = @{}
    foreach ($p in $raw.PSObject.Properties) { $map[$p.Name] = $p.Value }
    return $map
  } catch { return @{} }
}

function Write-UsageCache {
  param($Map)
  Write-TextFileAtomic $script:UsageCachePath (([PSCustomObject]$Map | ConvertTo-Json -Depth 4) + "`n")
}

function Update-UsageCache {
  param([scriptblock]$Change)
  $dir = Split-Path $script:UsageCachePath
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $fs = Enter-FileLock ($script:UsageCachePath + ".lock") $script:UsageCacheLockMs
  if ($null -eq $fs) { return }
  try {
    $map = Read-UsageCache
    & $Change $map
    Write-UsageCache $map
  } finally { $fs.Dispose() }
}

function Save-UsageEntry {
  param([string]$Label, $Usage)
  $at = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  Update-UsageCache {
    param($map)
    $map[$Label] = [PSCustomObject]@{
      At = $at
      Pct5 = $Usage.Pct5; Reset5 = $Usage.Reset5; Pct7 = $Usage.Pct7; Reset7 = $Usage.Reset7
      Fails = 0; Until = 0
    }
  }
}

function Save-UsageCooldown {
  param([string]$Label, [int]$Seconds, [int]$Fails)
  $until = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() + $Seconds
  Update-UsageCache {
    param($map)
    $old = $map[$Label]
    $map[$Label] = [PSCustomObject]@{
      At = [long]$old.At; Pct5 = $old.Pct5; Reset5 = $old.Reset5; Pct7 = $old.Pct7; Reset7 = $old.Reset7
      Fails = $Fails; Until = $until
    }
  }
}

function Rename-UsageEntry {
  param([string]$Old, [string]$New)
  Update-UsageCache {
    param($map)
    if (-not $map.ContainsKey($Old)) { return }
    $entry = $map[$Old]
    $map.Remove($Old)
    $map[$New] = $entry
  }
}

function Get-CooldownSeconds {
  param([int]$Fails, [int]$RetryAfter, [int]$Jitter)
  $back = [math]::Min($script:CooldownMaxSec, $script:CooldownBaseSec * [math]::Pow(2, $Fails - 1)) + $Jitter
  return [int][math]::Max($back, [math]::Min($RetryAfter, $script:RetryAfterMaxSec))
}

function Get-CooldownLeft {
  param($Entry)
  if ($null -eq $Entry) { return 0 }
  return [int][math]::Max(0, [long]$Entry.Until - [DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
}

function Get-CacheAge {
  param($Entry)
  return [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - [long]$Entry.At
}

function Copy-CacheEntry {
  param($Entry, $Out)
  $Out.Pct5 = $Entry.Pct5; $Out.Reset5 = $Entry.Reset5
  $Out.Pct7 = $Entry.Pct7; $Out.Reset7 = $Entry.Reset7
  $Out.Age = Get-CacheAge $Entry
  $now = [DateTimeOffset]::UtcNow
  foreach ($k in @("5", "7")) {
    $r = ConvertTo-DateOffset $Out.("Reset" + $k)
    if ($null -ne $r -and $r -le $now) { $Out.("Pct" + $k) = 0; $Out.("Reset" + $k) = $null; $Out.Expired = $true }
  }
}

function Format-Age {
  param($Seconds)
  if ($Seconds -lt 60) { return "" + $Seconds + "s" }
  if ($Seconds -lt 3600) { return "" + [math]::Floor($Seconds / 60) + "min" }
  return "" + [math]::Floor($Seconds / 3600) + "h"
}
