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

function Get-PaceSegs {
  param($Item, [string]$Lead)
  return @(@(($Lead + $Item[0] + " "), $script:Ink.Text, $true), @($Item[1].Text, (Get-PaceInk $Item[1].Tone), $false))
}

function Write-PaceLines {
  param([object[]]$Items)
  $segs = @(); $len = 0
  foreach ($it in $Items) {
    $lead = "   "
    if ($segs.Count -eq 0) { $lead = "       " }
    foreach ($s in Get-PaceSegs $it $lead) { $segs += , $s; $len += $s[0].Length }
  }
  if ($len -le $script:ViewWidth) { Write-Segs $segs; return }
  foreach ($it in $Items) { Write-Segs (Get-PaceSegs $it "       ") }
}

function Write-UsageLine {
  param($U)
  $a = Get-UsageSeg "5h" $U.Pct5 $U.Reset5
  $b = Get-UsageSeg "7d" $U.Pct7 $U.Reset7
  $p5 = Get-UsagePace "5h" $U.Pct5 $U.Reset5
  $p7 = Get-UsagePace "7d" $U.Pct7 $U.Reset7
  $v5 = Get-PaceSeg $p5
  $v7 = Get-PaceSeg $p7
  $sep = (Fg $script:Ink.Text $true) + " | "
  $used = 7 + $a[1] + $v5[1] + 3 + $b[1] + $v7[1]
  $inline = $used -le $script:ViewWidth
  if (-not $inline) { $v5 = @("", 0); $v7 = @("", 0); $used = 7 + $a[1] + 3 + $b[1] }
  $pad = [math]::Max(0, $script:ViewWidth - $used)
  Write-Host ("       " + $a[0] + $v5[0] + $sep + $b[0] + $v7[0] + (" " * $pad) + $script:Esc + "[0m")
  if ($inline) { return }
  $items = @()
  if ($p5 -ne $null) { $items += , @("5h", $p5) }
  if ($p7 -ne $null) { $items += , @("7d", $p7) }
  Write-PaceLines $items
}
