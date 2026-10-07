function Get-UsageSeg {
  param([string]$Kind, $Pct, $Reset)
  $bar = Get-Bar $Kind $Pct
  $txt = Fg $script:Ink.Text $true
  $tail = " " + ("" + [int]$Pct + "%").PadRight(4) + " " + (Format-Left $Reset).PadRight(6)
  return @(($txt + $Kind + " " + $bar + $txt + $tail), ($Kind.Length + 1 + $script:Cells + $tail.Length))
}

function Get-PaceInk {
  param([string]$Tone)
  if ($Tone -eq "ok") { return $script:Levels["7d"][0] }
  if ($Tone -eq "warn") { return $script:Levels["7d"][1] }
  if ($Tone -eq "alert") { return $script:Ink.Alert }
  return $script:Ink.Dim
}

function Get-PaceSeg {
  param($Pace)
  if ($Pace -eq $null) { return @("", 0) }
  return @(((Fg (Get-PaceInk $Pace.Tone)) + "  " + $Pace.Text), (2 + $Pace.Text.Length))
}

function Write-UsageLine {
  param($U)
  $a = Get-UsageSeg "5h" $U.Pct5 $U.Reset5
  $b = Get-UsageSeg "7d" $U.Pct7 $U.Reset7
  $v5 = Get-PaceSeg (Get-UsagePace "5h" $U.Pct5 $U.Reset5)
  $v7 = Get-PaceSeg (Get-UsagePace "7d" $U.Pct7 $U.Reset7)
  $sep = (Fg $script:Ink.Text $true) + " | "
  $pad = [math]::Max(0, $script:ViewWidth - (7 + $a[1] + $v5[1] + 3 + $b[1] + $v7[1]))
  Write-Host ("       " + $a[0] + $v5[0] + $sep + $b[0] + $v7[0] + (" " * $pad) + $script:Esc + "[0m")
}
