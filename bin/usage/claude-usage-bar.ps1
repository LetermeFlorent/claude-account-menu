function Get-KnownUsage {
  param($Acc, $Cache)
  return $Cache[$Acc.Label]
}

function New-UsageRow {
  param($Acc, [string]$Email = "")
  if ($Email -eq "") { $Email = Get-AccountEmail $Acc }
  return [PSCustomObject]@{ Label = $Acc.Label; Email = $Email; Acc = $Acc; Plan = ""; Pct5 = $null; Reset5 = $null; Pct7 = $null; Reset7 = $null; No5 = $false; Error = $null; Age = $null; At = $null; Expired = $false; LimitedUntil = $null }
}

function Get-LatestUsage {
  param($Acc)
  $known = Get-KnownUsage $Acc (Read-UsageCache)
  if ($null -eq $known) { return $null }
  $row = New-UsageRow $Acc
  Copy-CacheEntry $known $row
  $row.At = [long]$known.At
  $left = Get-CooldownLeft $known
  if ($left -gt 0) { $row.LimitedUntil = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() + $left }
  return $row
}
