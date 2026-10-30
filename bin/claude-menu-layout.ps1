$script:MenuMaxWidth = 105
$script:MenuMinWidth = 38

function Get-Clamped {
  param([int]$V, [int]$Min, [int]$Max)
  return [math]::Max($Min, [math]::Min($Max, $V))
}

function Get-MenuLayout {
  param([int]$Cols, [int]$Rows, [int]$Count, [int]$Extra = 0)
  $n = [math]::Max(1, $Count)
  $inner = $Cols - 1 - $script:FrameCols
  $w = Get-Clamped $inner $script:MenuMinWidth $script:MenuMaxWidth
  $foot = (Get-FooterRows (Get-MenuFooter) $w).Count
  $fixed = 7 + $foot + $Extra
  $l = @{ W = $w; FooterRows = $foot; Clip = [math]::Max(1, $Cols - 1); Visible = $n; Cells = 0 }
  if ($inner -lt $script:MenuMinWidth -or $Rows -lt $fixed + 3) {
    $l.Mode = "simple"; $l.Per = 1
    $l.Visible = [math]::Max(1, [math]::Min($n, $Rows - 2 - $Extra))
  } elseif ($fixed + 5 * $n -le $Rows) {
    $l.Mode = "full"; $l.Per = 5
    $l.Cells = Get-Clamped ($w - 34) 8 48
  } else {
    $l.Mode = "compact"; $l.Per = 3
    $l.Visible = [math]::Max(1, [math]::Min($n, [math]::Floor(($Rows - $fixed) / 3)))
    $l.Cells = Get-Clamped ([math]::Floor(($w - 60) / 2)) 4 20
  }
  return $l
}

function Get-ScrollTop {
  param([int]$Sel, [int]$Top, [int]$Visible, [int]$Count)
  if ($Sel -lt $Top) { $Top = $Sel }
  if ($Sel -ge $Top + $Visible) { $Top = $Sel - $Visible + 1 }
  return Get-Clamped $Top 0 ([math]::Max(0, $Count - $Visible))
}

function Get-ReadyDefault {
  param($Entries, [bool]$Wait = $true)
  for ($i = 0; $i -lt $Entries.Count; $i++) {
    $e = $Entries[$i]
    if ($e.Pending -and $Wait) { return -1 }
    $u = $e.U
    if ($null -eq $u.Error -and [int]$u.Pct5 -lt 100 -and [int]$u.Pct7 -lt 100) { return $i }
  }
  return 0
}
