. Import-ClmModule claude-text
$script:WindowSeconds = @{ "5h" = 18000; "7d" = 604800 }
$script:Invariant = [Globalization.CultureInfo]::InvariantCulture

function ConvertTo-DateOffset {
  param($Value)
  if ($null -eq $Value) { return $null }
  if ($Value -is [DateTimeOffset]) { return $Value }
  if ($Value -is [DateTime]) {
    if ($Value.Kind -eq [DateTimeKind]::Unspecified) { $Value = [DateTime]::SpecifyKind($Value, [DateTimeKind]::Local) }
    return [DateTimeOffset]$Value
  }
  $s = "" + $Value
  if ($s -eq "") { return $null }
  try { return [DateTimeOffset]::Parse($s, $script:Invariant) } catch { return $null }
}

function New-Pace {
  param([string]$Code, [string]$Tone)
  return [PSCustomObject]@{ Code = $Code; Text = (Get-ClmText ("ui.pace." + $Code)); Tone = $Tone }
}

function Get-UsagePace {
  param([string]$Kind, $Pct, $Reset, $Now = $null)
  if ($null -eq $Now) { $Now = [DateTimeOffset]::Now }
  $r = ConvertTo-DateOffset $Reset
  if ($null -eq $Pct -or "" + $Pct -eq "" -or $null -eq $r) { return $null }
  $dur = $script:WindowSeconds[$Kind]
  $left = ($r - $Now).TotalSeconds
  if ($left -le 0) { return $null }
  $p = [double]$Pct
  if ($p -ge 100) { return New-Pace "epuise" "alert" }
  $part = ($dur - $left) / $dur
  if ($part -lt 0.10) { return New-Pace "debut" "dim" }
  $projectedPct = $p / $part
  if ($projectedPct -lt 70) { return New-Pace "faible" "ok" }
  if ($projectedPct -le 100) { return New-Pace "normal" "dim" }
  if ($projectedPct -le 130) { return New-Pace "fort" "warn" }
  return New-Pace "excessif" "alert"
}
