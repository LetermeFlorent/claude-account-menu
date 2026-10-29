. Import-ClmModule claude-usage-pace, claude-usage-cache

function Format-Reset {
  param($Iso)
  $at = ConvertTo-DateOffset $Iso
  if ($null -eq $at) { return "-" }
  $dt = $at.LocalDateTime
  $now = Get-Date
  $span = $dt - $now
  $hhmm = $dt.ToString("HH:mm")
  if ($span.TotalSeconds -le 0) { return "$hhmm (passe)" }
  $h = [math]::Floor($span.TotalHours)
  $m = $span.Minutes
  $mm = "{0:D2}" -f $m
  if ($h -ge 24) {
    $d = [math]::Floor($h / 24)
    return $dt.ToString("dd/MM HH:mm") + " (dans " + $d + "j" + ($h % 24) + "h)"
  }
  return "$hhmm (dans " + $h + "h" + $mm + ")"
}

function Format-Row {
  param($U)
  $line = $U.Label + " " + $U.Email + " " + $U.Plan + " | "
  if ($null -ne $U.Error) { return $line + $U.Error }
  $line = $line + "5h " + $U.Pct5 + "% reset " + (Format-Reset $U.Reset5) + (Format-PaceSuffix "5h" $U.Pct5 $U.Reset5)
  $line = $line + " | 7d " + $U.Pct7 + "% reset " + (Format-Reset $U.Reset7) + (Format-PaceSuffix "7d" $U.Pct7 $U.Reset7)
  return $line + (Format-Stale $U)
}

function Format-PaceSuffix {
  param([string]$Kind, $Pct, $Reset)
  $p = Get-UsagePace $Kind $Pct $Reset
  if ($null -eq $p) { return "" }
  return ", " + $p.Text
}

function Format-Stale {
  param($U)
  if ($U.Expired) { return " (fenetre passee, lu il y a " + (Format-Age $U.Age) + ")" }
  if ($null -eq $U.Age -or $U.Age -lt 60) { return "" }
  return " (lu il y a " + (Format-Age $U.Age) + ")"
}
