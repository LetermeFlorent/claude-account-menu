$script:RereadMs = 120000

function New-MenuEntry {
  param($Acc, $Cache, [double]$Now)
  $u = [PSCustomObject]@{ Label = $Acc.Label; Email = (Get-AccountEmail $Acc); Acc = $Acc; Plan = ""; Pct5 = $null; Reset5 = $null; Pct7 = $null; Reset7 = $null; Error = $null; Age = $null; Expired = $false }
  $e = @{ Acc = $Acc; U = $u; Pending = $true; Seen = $false; View = $null; In = $null }
  $c = $Cache[$Acc.Label]
  if ($c -ne $null -and (Get-CacheAge $c) -lt $script:UsageCacheTtl) {
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
    if ($Open) { $e.In = New-Tween 0 1 220 ($Now + 45 * $entries.Count) }
    $entries.Add($e)
  }
  $moved = $Sel -ge 0
  if (-not $moved) { $Sel = Get-ReadyDefault $entries $false }
  $Sel = [math]::Max(0, [math]::Min($Sel, $entries.Count - 1))
  return @{
    Entries = $entries; Sel = $Sel; SelTween = (New-Tween $Sel $Sel 0 $Now); Moved = $moved; Top = 0
    Msg = @("", $script:Ink.Dim); Busy = $false; Dirty = $true; Loader = $null; DoneAt = $null
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
  if ($Res[2] -ne $null) { $e.U.Error = "" + $Res[2] } else { $e.U = $Res[1] }
  $e.Pending = $false
  $p5 = [double]$e.U.Pct5
  $p7 = [double]$e.U.Pct7
  if ($e.Seen) {
    Set-TweenTarget $e.T5 $p5 300 $Now
    Set-TweenTarget $e.T7 $p7 300 $Now
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
  param($State)
  $accs = New-Object 'System.Collections.Generic.List[object]'
  foreach ($e in $State.Entries) { $accs.Add($e.Acc) }
  $State.Loader = Start-UsageLoader $accs.ToArray()
}

function Step-MenuLoader {
  param($State, [double]$Now)
  $ld = $State.Loader
  if ($ld -eq $null) {
    if ($State.DoneAt -ne $null -and -not $State.Busy -and $Now - $State.DoneAt -ge $script:RereadMs) {
      foreach ($e in $State.Entries) { $e.Pending = $true }
      $State.DoneAt = $null
      Start-MenuLoader $State
    }
    return
  }
  foreach ($r in (Receive-UsageResults $ld)) { Set-UsageResult $State $r $Now }
  if (-not $ld.Ctl.Done -or -not $ld.Queue.IsEmpty) { return }
  Close-UsageLoader $ld
  $State.Loader = $null
  $State.DoneAt = $Now
  foreach ($e in $State.Entries) {
    if ($e.Pending -and $ld.Ctl.Error -ne $null) { $e.Pending = $false; $e.U.Error = "lecture impossible : " + $ld.Ctl.Error; Update-EntryView $e; $State.Dirty = $true }
  }
}
