. Import-ClmModule claude-usage-pace, claude-usage-cache, claude-text

function Format-Reset {
  param($Iso)
  $at = ConvertTo-DateOffset $Iso
  if ($null -eq $at) { return "-" }
  $dt = $at.LocalDateTime
  $now = Get-Date
  $span = $dt - $now
  $hhmm = $dt.ToString("HH:mm")
  if ($span.TotalSeconds -le 0) { return Get-ClmText "ui.reset.past" $hhmm }
  $h = [math]::Floor($span.TotalHours)
  $m = $span.Minutes
  $mm = "{0:D2}" -f $m
  if ($h -ge 24) {
    $d = [math]::Floor($h / 24)
    return Get-ClmText "ui.reset.inDays" @($dt.ToString("dd/MM HH:mm"), $d, ($h % 24))
  }
  return Get-ClmText "ui.reset.inHours" @($hhmm, $h, $mm)
}

function Format-Row {
  param($U)
  $line = $U.Label + " " + $U.Email + " " + $U.Plan + " | "
  if ($null -ne $U.Error) { return $line + $U.Error }
  $line = $line + (Get-ClmText "ui.row.window" @("5h", $U.Pct5, (Format-Reset $U.Reset5))) + (Format-PaceSuffix "5h" $U.Pct5 $U.Reset5)
  $line = $line + " | " + (Get-ClmText "ui.row.window" @("7d", $U.Pct7, (Format-Reset $U.Reset7))) + (Format-PaceSuffix "7d" $U.Pct7 $U.Reset7)
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
  if ($U.Expired) { return " (" + (Get-ClmText "ui.stale.expired" (Format-Age $U.Age)) + ")" }
  if ($null -eq $U.Age -or $U.Age -lt 60) { return "" }
  return " (" + (Get-ClmText "ui.stale.read" (Format-Age $U.Age)) + ")"
}
