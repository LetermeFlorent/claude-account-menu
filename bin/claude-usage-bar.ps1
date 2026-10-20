function Read-StatusLines {
  param([string]$Path)
  $map = @{}
  try {
    $fs = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]"ReadWrite, Delete")
    try { $text = (New-Object IO.StreamReader($fs)).ReadToEnd() } finally { $fs.Dispose() }
  } catch { return $map }
  foreach ($line in $text.Split("`n")) {
    $i = $line.IndexOf(" ")
    if ($i -gt 0) { $map[$line.Substring(0, $i)] = $line.Substring($i + 1).TrimEnd("`r") }
  }
  return $map
}

function ConvertTo-StatusNumber {
  param([string]$Text)
  $v = 0.0
  if (-not [double]::TryParse($Text, [Globalization.NumberStyles]::Float, $script:Invariant, [ref]$v)) { return $null }
  if ([double]::IsNaN($v) -or [double]::IsInfinity($v)) { return $null }
  return $v
}

function Read-StatusUsage {
  param($Acc)
  $map = Read-StatusLines (Get-StatusStatePath)
  $tag = "@" + (Get-StateTag (Get-AccountPath $Acc))
  $at = ConvertTo-StatusNumber $map["q_at" + $tag]
  if ($null -eq $at) { return $null }
  $e = [PSCustomObject]@{ At = [long][math]::Floor($at); Pct5 = $null; Reset5 = $null; Pct7 = $null; Reset7 = $null; Fails = 0; Until = 0 }
  $found = $false
  foreach ($k in @("5", "7")) {
    $reset = ConvertTo-StatusNumber $map["q" + $k + "_at" + $tag]
    $pct = ConvertTo-StatusNumber $map["q" + $k + "_pct" + $tag]
    if ($null -eq $reset -or $null -eq $pct) { continue }
    $e.("Pct" + $k) = [math]::Round($pct)
    $e.("Reset" + $k) = [DateTimeOffset]::FromUnixTimeMilliseconds([long][math]::Round($reset * 1000)).ToString("o", $script:Invariant)
    $found = $true
  }
  if (-not $found) { return $null }
  return $e
}

function Select-NewestUsage {
  param($Cached, $Bar)
  if ($null -eq $Bar -or ($null -ne $Cached -and [long]$Cached.At -ge $Bar.At)) { return $Cached }
  if ($null -ne $Cached) { $Bar.Fails = [int]$Cached.Fails; $Bar.Until = [long]$Cached.Until }
  return $Bar
}

function Get-KnownUsage {
  param($Acc, $Cache)
  return Select-NewestUsage $Cache[$Acc.Label] (Read-StatusUsage $Acc)
}
