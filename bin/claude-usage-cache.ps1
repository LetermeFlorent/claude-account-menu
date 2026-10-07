. (Join-Path $PSScriptRoot "claude-platform.ps1")
$script:UsageCachePath = Get-UsageCachePath
$script:UsageCacheTtl = 120

function Read-UsageCache {
  if (-not (Test-Path -LiteralPath $script:UsageCachePath)) { return @{} }
  try {
    $raw = Get-Content -LiteralPath $script:UsageCachePath -Raw | ConvertFrom-Json
    $map = @{}
    foreach ($p in $raw.PSObject.Properties) { $map[$p.Name] = $p.Value }
    return $map
  } catch { return @{} }
}

function Save-UsageEntry {
  param([string]$Label, $Usage)
  $map = Read-UsageCache
  $map[$Label] = [PSCustomObject]@{
    At = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    Pct5 = $Usage.Pct5; Reset5 = $Usage.Reset5; Pct7 = $Usage.Pct7; Reset7 = $Usage.Reset7
  }
  $dir = Split-Path $script:UsageCachePath
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  [PSCustomObject]$map | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $script:UsageCachePath -Encoding UTF8
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
}

function Format-Age {
  param($Seconds)
  if ($Seconds -lt 60) { return "" + $Seconds + "s" }
  if ($Seconds -lt 3600) { return "" + [math]::Floor($Seconds / 60) + "min" }
  return "" + [math]::Floor($Seconds / 3600) + "h"
}
