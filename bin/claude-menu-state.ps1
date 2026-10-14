
function New-MenuEntry {
  param($Acc, $Cache, [double]$Now)
  $u = [PSCustomObject]@{ Label = $Acc.Label; Email = (Get-AccountEmail $Acc); Acc = $Acc; Plan = ""; Pct5 = $null; Reset5 = $null; Pct7 = $null; Reset7 = $null; Error = $null; Age = $null; Expired = $false; LimitedUntil = $null }
  $e = @{ Acc = $Acc; U = $u; Pending = $true; Seen = $false; View = $null; In = $null; NextAt = $null; Slot = 0; Timer = $null }
  $c = $Cache[$Acc.Label]
  if ($null -ne $c -and (Get-CacheAge $c) -lt $script:UsageCacheTtl) {
    Copy-CacheEntry $c $u
    $e.Seen = $true
    $e.T5 = New-Tween 0 ([double]$u.Pct5) 400 $Now
    $e.T7 = New-Tween 0 ([double]$u.Pct7) 400 $Now
  } else {
    $e.T5 = New-Tween 0 0 0 $Now
    $e.T7 = New-Tween 0 0 0 $Now
  }
  Update-EntryView $e
  return $e
}

function New-MenuState {
  param($Accs, [double]$Now, [bool]$Open = $true, [int]$Sel = -1)
  $cache = Read-UsageCache
  $entries = New-Object 'System.Collections.Generic.List[object]'
  foreach ($a in $Accs) {
    $e = New-MenuEntry $a $cache $Now
    $e.Slot = $script:RereadMs * $entries.Count / [math]::Max(1, @($Accs).Count)
    if ($Open) { $e.In = New-Tween 0 1 220 ($Now + 45 * $entries.Count) }
    $entries.Add($e)
  }
  $moved = $Sel -ge 0
  if (-not $moved) { $Sel = Get-ReadyDefault $entries $false }
  $Sel = [math]::Max(0, [math]::Min($Sel, $entries.Count - 1))
  return @{
    Entries = $entries; Sel = $Sel; SelTween = (New-Tween $Sel $Sel 0 $Now); Moved = $moved; Top = 0
    Msg = @("", $script:Ink.Dim); Busy = $false; Dirty = $true; Loader = $null; LoaderIdx = @(); Clock = $null; Version = (Get-ClmTag)
  }
}

function Move-MenuSel {
  param($State, [int]$To, [double]$Now, [bool]$User)
  if ($User) { $State.Moved = $true }
  if ($To -eq $State.Sel) { return }
  $State.Sel = $To
  Set-TweenTarget $State.SelTween $To 120 $Now
  $State.Dirty = $true
}

function Set-UsageResult {
  param($State, $Res, [double]$Now)
  $e = $State.Entries[[int]$Res[0]]
  if ($null -ne $Res[2]) { $e.U.Error = "" + $Res[2] } else { $e.U = $Res[1] }
  $e.Pending = $false
  $e.NextAt = Get-NextReadAt $e $Now
  $p5 = [double]$e.U.Pct5
  $p7 = [double]$e.U.Pct7
  if ($e.Seen) {
    if ($e.T5.To -ne $p5) { Set-TweenTarget $e.T5 $p5 300 $Now }
    if ($e.T7.To -ne $p7) { Set-TweenTarget $e.T7 $p7 300 $Now }
  } else {
    $e.T5 = New-Tween 0 $p5 400 $Now
    $e.T7 = New-Tween 0 $p7 400 $Now
    $e.Seen = $true
  }
  Update-EntryView $e
  $State.Dirty = $true
  if ($State.Moved) { return }
  $d = Get-ReadyDefault $State.Entries
  if ($d -ge 0) { Move-MenuSel $State $d $Now $false }
}

function Start-MenuLoader {
  param($State, $Indices = $null)
  if ($null -eq $Indices) { $Indices = 0..($State.Entries.Count - 1) }
  $accs = New-Object 'System.Collections.Generic.List[object]'
  foreach ($i in $Indices) { $e = $State.Entries[$i]; $e.Pending = $true; $e.NextAt = $null; $accs.Add($e.Acc) }
  $State.LoaderIdx = @($Indices)
  $State.Loader = Start-UsageLoader $accs.ToArray()
}

function Get-DueEntries {
  param($State, [double]$Now)
  return @(for ($i = 0; $i -lt $State.Entries.Count; $i++) {
    $at = $State.Entries[$i].NextAt
    if ($null -ne $at -and $Now -ge $at) { $i }
  })
}

function Step-MenuLoader {
  param($State, [double]$Now)
  $ld = $State.Loader
  if ($null -eq $ld) {
    if ($State.Busy) { return }
    $due = Get-DueEntries $State $Now
    if ($due.Count -gt 0) { Start-MenuLoader $State $due }
    return
  }
  foreach ($r in (Receive-UsageResults $ld)) { Set-UsageResult $State @($State.LoaderIdx[[int]$r[0]], $r[1], $r[2]) $Now }
  if (-not $ld.Ctl.Done -or -not $ld.Queue.IsEmpty) { return }
  Close-UsageLoader $ld
  $State.Loader = $null
  foreach ($i in $State.LoaderIdx) {
    $e = $State.Entries[$i]
    if (-not $e.Pending) { continue }
    if ($null -ne $ld.Ctl.Error) { $e.U.Error = "lecture impossible : " + $ld.Ctl.Error }
    $e.Pending = $false
    $e.NextAt = Get-NextReadAt $e $Now
    Update-EntryView $e
    $State.Dirty = $true
  }
}
