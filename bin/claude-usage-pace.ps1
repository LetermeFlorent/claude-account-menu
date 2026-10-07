$script:WindowSeconds = @{ "5h" = 18000; "7d" = 604800 }
$script:Invariant = [Globalization.CultureInfo]::InvariantCulture

function ConvertTo-DateOffset {
  param($Value)
  if ($Value -eq $null) { return $null }
  if ($Value -is [DateTimeOffset]) { return $Value }
  if ($Value -is [DateTime]) {
    if ($Value.Kind -eq [DateTimeKind]::Unspecified) { $Value = [DateTime]::SpecifyKind($Value, [DateTimeKind]::Local) }
    return [DateTimeOffset]$Value
  }
  $s = "" + $Value
  if ($s -eq "") { return $null }
  try { return [DateTimeOffset]::Parse($s, $script:Invariant) } catch { return $null }
}

function Format-CutTime {
  param([DateTimeOffset]$At, [DateTimeOffset]$Now)
  $a = $At.ToLocalTime()
  if ($a.Date -eq $Now.ToLocalTime().Date) { return $a.ToString("HH:mm", $script:Invariant) }
  return $a.ToString("dd/MM HH:mm", $script:Invariant)
}

function New-Pace {
  param([string]$Text, [string]$Tone)
  return [PSCustomObject]@{ Text = $Text; Tone = $Tone }
}

function Get-UsagePace {
  param([string]$Kind, $Pct, $Reset, $Now = $null)
  if ($Now -eq $null) { $Now = [DateTimeOffset]::Now }
  $r = ConvertTo-DateOffset $Reset
  if ($Pct -eq $null -or "" + $Pct -eq "" -or $r -eq $null) { return $null }
  $dur = $script:WindowSeconds[$Kind]
  $left = ($r - $Now).TotalSeconds
  if ($left -le 0) { return $null }
  $p = [double]$Pct
  if ($p -ge 100) { return New-Pace "coupe jusqu'au reset" "alert" }
  $elapsed = $dur - $left
  $part = $elapsed / $dur
  if ($part -lt 0.10) { return New-Pace "trop tot" "dim" }
  $proj = $p / $part
  if ($proj -lt 70) { return New-Pace "large" "ok" }
  if ($proj -le 100) { return New-Pace "bon rythme" "dim" }
  $unit = 3600; $suffix = "%/h"
  if ($Kind -eq "7d") { $unit = 86400; $suffix = "%/j" }
  $max = "max " + [int][math]::Round((100 - $p) / $left * $unit, 0, [MidpointRounding]::AwayFromZero) + $suffix
  if ($proj -le 130) { return New-Pace ("agressif, " + $max) "warn" }
  $cut = $Now.AddSeconds((100 - $p) / ($p / $elapsed))
  return New-Pace ("trop, coupe vers " + (Format-CutTime $cut $Now) + ", " + $max) "alert"
}
