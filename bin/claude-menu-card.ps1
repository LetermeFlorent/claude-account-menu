function Get-SegsLength {
  param($Row)
  $n = 0
  foreach ($s in $Row) { $n += $s[0].Length }
  return $n
}

function Add-RightSegs {
  param($Row, [int]$End, [object[]]$Right)
  $used = Get-SegsLength $Row
  $k = 0
  $len = 0
  while ($k -lt $Right.Count) {
    $len = 0
    for ($j = $k; $j -lt $Right.Count; $j++) { $len += $Right[$j][0].Length }
    if ($used + 2 + $len -le $End) { break }
    $k++
  }
  if ($k -ge $Right.Count -or $len -eq 0) { return }
  $Row.Add(@((" " * ($End - $used - $len)), $script:Ink.Text, $false))
  for ($j = $k; $j -lt $Right.Count; $j++) { $Row.Add($Right[$j]) }
}

function Update-EntryView {
  param($E)
  $E.View = Get-UsageView $E.U
}

function Add-WaitSegs {
  param($Row, [string]$Kind, [int]$C, [double]$Now)
  $Row.Add(@(($Kind + " "), $script:Ink.Text, $true))
  Add-ShimmerSegs $Row $C $Now
}

function Get-CardBody {
  param($E, $L, [double]$Now)
  $u = $E.U
  $v = $E.View
  $rows = New-Object 'System.Collections.Generic.List[object]'
  $n = 2
  if ($L.Mode -eq "compact") { $n = 1 }
  for ($i = 0; $i -lt $n; $i++) { $r = New-Row; $r.Add(@("       ", $script:Ink.Text, $false)); $rows.Add($r) }
  if ($null -ne $u.Error) {
    $rows[0].Add(@(("" + $u.Error), $script:Ink.Alert, $false))
  } elseif ($E.Pending -and -not $E.Seen) {
    Add-WaitSegs $rows[0] "5h" $L.Cells $Now
    if ($n -eq 1) { $rows[0].Add(@("   ", $script:Ink.Text, $false)); Add-WaitSegs $rows[0] "7d" $L.Cells $Now }
    else { Add-WaitSegs $rows[1] "7d" $L.Cells $Now }
    $rows[0].Add(@("  lecture...", $script:Ink.Dim, $false))
  } elseif ($n -eq 1) {
    $rows[0].AddRange((Get-CompactUsageSegs $u $L.Cells $v $E.T5 $E.T7 $Now))
  } else {
    Add-UsageSegs $rows[0] "5h" $E.T5 $v.Left5 $v.Pace5 $L.Cells $Now $true
    Add-UsageSegs $rows[1] "7d" $E.T7 $v.Left7 $v.Pace7 $L.Cells $Now $true
  }
  return ,$rows
}

function Add-CardRows {
  param($Rows, $Fades, $E, [int]$I, $L, [double]$P, [double]$Now)
  $w = [math]::Max(0, 1 - [math]::Abs($P - $I))
  $fade = 1 - 0.35 * (1 - $w)
  if ($null -ne $E.In) { $fade = $fade * (Get-TweenValue $E.In $Now) }
  $u = $E.U
  $v = $E.View
  $txt = $script:Ink.Text
  $end = $L.W - 2
  $mail = @(("" + $u.Email), (Get-MixedRgb $script:Ink.Dim $txt $w), ($w -gt 0.5))
  $plan = @(("" + $u.Plan), (Get-PlanColor $u.Plan), $true)
  $badge = @("", $script:Ink.Alert, $true)
  if ($v.Badge) { $badge[0] = $v.Badge + "  " }
  $note = @("", $script:Ink.Dim, $false)
  if ($v.Note) { $note[0] = $v.Note + "  " }
  $head = New-Row
  $head.Add(@("    ", $txt, $false))
  $head.Add(@(("" + ($I + 1) + "  " + $u.Label), $txt, ($w -gt 0.5)))
  $out = New-Object 'System.Collections.Generic.List[object]'
  $out.Add($head)
  if ($L.Mode -eq "compact") {
    $head.Add(@("  ", $txt, $false))
    $head.Add($mail)
    Add-RightSegs $head $end @($note, $badge, $plan)
  } else {
    Add-RightSegs $head $end @($badge, $plan)
    $r = New-Row
    $r.Add(@("       ", $txt, $false))
    $r.Add($mail)
    Add-RightSegs $r $end @(, $note)
    $out.Add($r)
  }
  $out.AddRange((Get-CardBody $E $L $Now))
  $out.Add((New-Row))
  foreach ($r in $out) { $Rows.Add($r); $Fades.Add($fade) }
}
