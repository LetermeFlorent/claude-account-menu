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
  if ($p -ge 100) { return New-Pace "epuise" "alert" }
  $part = ($dur - $left) / $dur
  if ($part -lt 0.10) { return New-Pace "debut" "dim" }
  # Pourcentage projete a la fin de la fenetre au rythme actuel
  $proj = $p / $part
  if ($proj -lt 70) { return New-Pace "faible" "ok" }
  if ($proj -le 100) { return New-Pace "normal" "dim" }
  if ($proj -le 130) { return New-Pace "fort" "warn" }
  return New-Pace "excessif" "alert"
}
