if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-platform.ps1")) { . (Join-Path $PSScriptRoot "claude-platform.ps1") }
$script:UsageCachePath = Get-UsageCachePath
$script:UsageCacheTtl = 180
$script:ForcedReadMaxAge = 30
$script:CooldownBaseSec = 60
$script:CooldownMaxSec = 600
$script:RetryAfterMaxSec = 3600

function Read-UsageCache {
  if (-not (Test-Path -LiteralPath $script:UsageCachePath)) { return @{} }
  try {
    $raw = Get-Content -LiteralPath $script:UsageCachePath -Raw | ConvertFrom-Json
    $map = @{}
    foreach ($p in $raw.PSObject.Properties) { $map[$p.Name] = $p.Value }
    return $map
  } catch { return @{} }
}

function Write-UsageCache {
  param($Map)
  $dir = Split-Path $script:UsageCachePath
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  [PSCustomObject]$Map | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $script:UsageCachePath -Encoding UTF8
}

function Save-UsageEntry {
  param([string]$Label, $Usage)
  $map = Read-UsageCache
  $map[$Label] = [PSCustomObject]@{
    At = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    Pct5 = $Usage.Pct5; Reset5 = $Usage.Reset5; Pct7 = $Usage.Pct7; Reset7 = $Usage.Reset7
    Fails = 0; Until = 0
  }
  Write-UsageCache $map
}

function Save-UsageCooldown {
  param([string]$Label, [int]$Seconds, [int]$Fails)
  $map = Read-UsageCache
  $old = $map[$Label]
  $map[$Label] = [PSCustomObject]@{
    At = [long]$old.At; Pct5 = $old.Pct5; Reset5 = $old.Reset5; Pct7 = $old.Pct7; Reset7 = $old.Reset7
    Fails = $Fails; Until = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() + $Seconds
  }
  Write-UsageCache $map
}

function Rename-UsageEntry {
  param([string]$Old, [string]$New)
  $map = Read-UsageCache
  if (-not $map.ContainsKey($Old)) { return }
  $entry = $map[$Old]
  $map.Remove($Old)
  $map[$New] = $entry
  Write-UsageCache $map
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
