function Get-PaceInk {
  param([string]$Tone)
  if ($Tone -eq "ok") { return $script:Levels["7d"][0] }
  if ($Tone -eq "warn") { return $script:Levels["7d"][1] }
  if ($Tone -eq "alert") { return $script:Ink.Alert }
  return $script:Ink.Dim
}

function Get-UsageView {
  param($U)
  $badge = ""
  if ($null -eq $U.Error -and [int]$U.Pct7 -ge 100) { $badge = "quota 7d atteint" }
  elseif ($null -eq $U.Error -and [int]$U.Pct5 -ge 100) { $badge = "quota 5h atteint" }
  $note = ""
  if ($null -ne $U.Age -and $U.Expired) { $note = "fenetre passee, lu il y a " + (Format-Age $U.Age) }
  elseif ($null -ne $U.Age -and $U.Age -ge 60) { $note = "lu il y a " + (Format-Age $U.Age) }
  return @{
    Left5 = Format-Left $U.Reset5; Left7 = Format-Left $U.Reset7
    Pace5 = Get-UsagePace "5h" $U.Pct5 $U.Reset5; Pace7 = Get-UsagePace "7d" $U.Pct7 $U.Reset7
    Badge = $badge; Note = $note
  }
}

function New-Row {
  return ,(New-Object 'System.Collections.Generic.List[object]')
}

function Add-UsageSegs {
  param($Segs, [string]$Kind, $Tween, [string]$Left, $Pace, [int]$C, [double]$Now, [bool]$Wide)
  $v = Get-TweenValue $Tween $Now
  $txt = $script:Ink.Text
  $gap = " "
  if ($Wide) { $gap = "  " }
  $Segs.Add(@(($Kind + " "), $txt, $true))
  Add-BarSegs $Segs $Kind $v (Get-BarBase $Kind $Tween $Now) $C
  $pct = [int][math]::Round($v)
  $pctInk = $txt
  if ($pct -ge 100) { $pctInk = $Segs[$Segs.Count - 1][1] }
  $Segs.Add(@(($gap + ("" + $pct + "%").PadLeft(4)), $pctInk, $true))
  $Segs.Add(@(($gap + $Left.PadRight(6)), $txt, $true))
  $word = ""
  $ink = $script:Ink.Dim
  if ($null -ne $Pace) { $word = $Pace.Text; $ink = Get-PaceInk $Pace.Tone }
  if (-not $Wide) { $word = $word.PadRight(8) }
  $Segs.Add(@(("  " + $word), $ink, $false))
}

function Get-CompactUsageSegs {
  param($U, [int]$Cells, $View = $null, $T5 = $null, $T7 = $null, [double]$Now = 0)
  if ($null -eq $View) { $View = Get-UsageView $U }
  if ($null -eq $T5) { $T5 = New-Tween ([double]$U.Pct5) ([double]$U.Pct5) 0 0 }
  if ($null -eq $T7) { $T7 = New-Tween ([double]$U.Pct7) ([double]$U.Pct7) 0 0 }
  $segs = New-Row
  Add-UsageSegs $segs "5h" $T5 $View.Left5 $View.Pace5 $Cells $Now $false
  $segs.Add(@(" | ", $script:Ink.Text, $true))
  Add-UsageSegs $segs "7d" $T7 $View.Left7 $View.Pace7 $Cells $Now $false
  return ,$segs
}
