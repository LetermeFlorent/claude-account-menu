. Import-ClmModule claude-menu-card-cache, claude-text, claude-ui-width
function Get-SegsLength {
  param($Row)
  $n = 0
  foreach ($s in $Row) { $n += Get-DisplayWidth $s[0] }
  return $n
}

function Add-RightSegs {
  param($Row, [int]$End, [object[]]$Right)
  $used = Get-SegsLength $Row
  $k = 0
  $len = 0
  while ($k -lt $Right.Count) {
    $len = 0
    for ($j = $k; $j -lt $Right.Count; $j++) { $len += Get-DisplayWidth $Right[$j][0] }
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
    $rows[0].Add(@(("  " + (Get-ClmText "menu.card.reading")), $script:Ink.Dim, $false))
  } elseif ($n -eq 1) {
    $rows[0].AddRange((Get-CompactUsageSegs @{ Usage = $u; Cells = $L.Cells; View = $v; Tween5 = $E.T5; Tween7 = $E.T7; Now = $Now }))
  } else {
    Add-UsageSegs @{ Segs = $rows[0]; Kind = "5h"; Tween = $E.T5; Left = $v.Left5; Pace = $v.Pace5; Cells = $L.Cells; Now = $Now; Wide = $true }
    Add-UsageSegs @{ Segs = $rows[1]; Kind = "7d"; Tween = $E.T7; Left = $v.Left7; Pace = $v.Pace7; Cells = $L.Cells; Now = $Now; Wide = $true }
  }
  return ,$rows
}

function New-TailSeg {
  param([string]$Text, $Ink, [bool]$Bold = $false)
  if ($Text) { $Text += "  " }
  return ,@($Text, $Ink, $Bold)
}

function Get-CardHead {
  param($E, [int]$I, $L, [double]$W)
  $u = $E.U
  $v = $E.View
  $txt = $script:Ink.Text
  $end = $L.W - 2
  $mail = @(("" + $u.Email), (Get-MixedRgb $script:Ink.Dim $txt $W), ($W -gt 0.5))
  $plan = @(("" + $u.Plan), (Get-PlanColor $u.Plan), $true)
  $badge = New-TailSeg $v.Badge $script:Ink.Alert $true
  $note = New-TailSeg $v.Note $script:Ink.Dim
  $away = New-TailSeg (Get-AccountAway $u.Acc) $script:Ink.Alert
  $timer = New-TailSeg "" $script:Ink.Dim
  if ($E.Timer) { $timer = New-TailSeg $E.Timer[0] $E.Timer[1] }
  $head = New-Row
  $head.Add(@("    ", $txt, $false))
  $head.Add(@(("" + ($I + 1) + "  " + $u.Label), $txt, ($W -gt 0.5)))
  $out = New-Object 'System.Collections.Generic.List[object]'
  $out.Add($head)
  if ($L.Mode -eq "compact") {
    $head.Add(@("  ", $txt, $false))
    $head.Add($mail)
    Add-RightSegs $head $end @($note, $away, $timer, $badge, $plan)
    return ,$out
  }
  Add-RightSegs $head $end @($away, $timer, $badge, $plan)
  $r = New-Row
  $r.Add(@("       ", $txt, $false))
  $r.Add($mail)
  Add-RightSegs $r $end @(, $note)
  $out.Add($r)
  return ,$out
}

function Add-CardRows {
  param($Request)
  $now = [double]$Request.Now
  $w = [math]::Max(0, 1 - [math]::Abs([double]$Request.Position - [int]$Request.Index))
  $fade = 1 - 0.35 * (1 - $w)
  if ($null -ne $Request.Entry.In) { $fade = $fade * (Get-TweenValue $Request.Entry.In $now) }
  $out = Get-CardRows $Request.Entry ([int]$Request.Index) $Request.Layout $w $now
  foreach ($r in $out) { $Request.Rows.Add($r); $Request.Fades.Add($fade) }
}
