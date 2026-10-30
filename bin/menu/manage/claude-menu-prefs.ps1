. Import-ClmModule claude-menu-prefs-data, claude-menu-prefs-pc, claude-text
$script:PrefsChrome = 14
$script:PrefsLabelWidth = 34

function Get-PrefsEraseWarn {
  param([string]$Kind)
  return "  " + (Get-ClmText ("sync.prefs.erase." + $Kind))
}

function Get-PrefsSub {
  param($Catalog)
  if (@($Catalog.Waiting).Count -gt 0) { return Get-ClmText "sync.prefs.sub.waiting" @((@($Catalog.Waiting) -join ", ")) }
  if (-not $Catalog.PerPc) { return Get-ClmText "sync.prefs.sub.perPc" }
  return Get-ClmText "sync.prefs.sub.checked"
}

function Get-PrefsItemRow {
  param($Item, [bool]$Sel)
  $ink = $script:Ink.Dim
  if ($Sel) { $ink = $script:Ink.Text }
  $r = New-Row
  $r.Add(@("    ", $ink, $false))
  if ($Item.On -and -not $Item.Erasing) { $r.Add(@(([string][char]0x25A0 + "  "), $script:Levels["7d"][0], $false)) }
  elseif ($Item.Mixed) { $r.Add(@(([string][char]0x25A0 + "  "), $script:Ink.Dim, $false)) }
  else { $r.Add(@(([string][char]0x25A1 + "  "), $script:Ink.Empty, $false)) }
  $r.Add(@((Limit-Text $Item.Label $script:PrefsLabelWidth).PadRight($script:PrefsLabelWidth), $ink, $Sel))
  if ($Item.Tag) { $r.Add(@(("  " + $Item.Tag), $script:Ink.Dim, $false)) }
  if ($Item.Erasing) { $r.Add(@(("  " + (Get-ClmText "sync.prefs.erasing")), $script:Ink.Alert, $false)) }
  if ($Item.Wait) { $r.Add(@(("  " + (Get-ClmText "sync.prefs.pc.wait")), $script:Ink.Dim, $false)) }
  if ($Sel) { Add-MarkSeg $r }
  return ,$r
}

function Get-PrefsWindow {
  param([int]$Count, [int]$Sel, [int]$Extra = 0)
  $max = [math]::Max(4, $script:UiRows - $script:PrefsChrome - $Extra)
  if ($Count -le $max) { return @(0, $Count) }
  $start = [math]::Max(0, [math]::Min($Sel - [int]($max / 2), $Count - $max))
  return @($start, ($start + $max))
}

function Get-PrefsRows {
  param($Lines, [int]$Sel, [int]$Extra = 0)
  $rows = New-Object 'System.Collections.Generic.List[object]'
  $win = Get-PrefsWindow $Lines.Count $Sel $Extra
  if ($win[0] -gt 0) { $rows.Add((New-TextRow ("    " + $script:UpArrow) $script:Ink.Dim)) }
  for ($i = $win[0]; $i -lt $win[1]; $i++) {
    $l = $Lines[$i]
    if ($l.Head) { $rows.Add((New-TextRow ("  " + $l.Label) $script:Ink.Text $true)) }
    else { $rows.Add((Get-PrefsItemRow $l ($i -eq $Sel))) }
  }
  if ($win[1] -lt $Lines.Count) { $rows.Add((New-TextRow ("    " + $script:DownArrow) $script:Ink.Dim)) }
  return ,$rows
}

function Move-PrefsSel {
  param($Lines, [int]$Sel, [int]$Step)
  $i = $Sel
  for ($n = 0; $n -lt $Lines.Count; $n++) {
    $i = ($i + $Step + $Lines.Count) % $Lines.Count
    if (-not $Lines[$i].Head) { return $i }
  }
  return $Sel
}

function Find-PrefsLine {
  param($Lines, $Item)
  for ($i = 0; $i -lt $Lines.Count; $i++) {
    if (-not $Lines[$i].Head -and $Lines[$i].Kind -eq $Item.Kind -and $Lines[$i].Key -ceq $Item.Key) { return $i }
  }
  return Move-PrefsSel $Lines -1 1
}

function Confirm-PrefsPage {
  param([string]$Ask, [string[]]$Lines)
  $body = @(foreach ($l in $Lines) { , (New-TextRow $l $script:Ink.Dim) })
  $k = Read-PageKey { Get-PageRows $Ask $body @("o", (Get-ClmText "sync.prefs.confirm.ok"), (Get-ClmText "sync.prefs.confirm.any"), (Get-ClmText "sync.prefs.confirm.cancel")) }
  return $k.KeyChar -eq "o"
}

function Show-PrefsEmpty {
  $body = @(, (New-TextRow ("  " + (Get-ClmText "sync.prefs.empty")) $script:Ink.Dim))
  $null = Read-PageKey { Get-PageRows (Get-ClmText "sync.prefs.title") $body @() }
  return Get-ClmText "sync.prefs.noneToShow"
}

function Invoke-PrefsKey {
  param($Ctx, $Key, $Item)
  $prefsCtx = $Ctx
  $prefsHit = $Item
  if ($Ctx.At -gt 0) {
    if ($Key.Key -ne "Spacebar") { return $false }
    if ($Item.On -and -not (Confirm-PrefsPage (Get-ClmText "sync.prefs.uncheck.ask" @($Item.Label)) (Get-PrefsOffLines $Item $Ctx.Pcs[$Ctx.At]))) { return $false }
    $Ctx.Choice = Update-SyncChoice { param($c) Set-PcPrefsCheck @{ Choice = $c; Catalog = $prefsCtx.Catalog; Me = $prefsCtx.Me; Pc = $prefsCtx.Pcs[$prefsCtx.At]; Item = $prefsHit; On = (-not $prefsHit.On) } }
    return $true
  }
  if ($Key.Key -eq "Spacebar") {
    if ($Item.On -and -not $Item.Erasing -and -not (Confirm-PrefsPage (Get-ClmText "sync.prefs.uncheck.ask" @($Item.Label)) (Get-PrefsOffLines $Item))) { return $false }
    $Ctx.Choice = Update-SyncChoice { param($c) Set-PrefsCheck $c $prefsHit }
    return $true
  }
  if ($Key.Key -ne "Delete" -or $Item.Erasing -or $Item.All -or -not (Confirm-PrefsPage (Get-ClmText "sync.prefs.erase.ask" @($Item.Label)) @(Get-PrefsEraseWarn $Item.Kind))) { return $false }
  $Ctx.Choice = Update-SyncChoice { param($c) Add-EraseRequest $c $prefsHit.Kind $prefsHit.Key }
  return $true
}

function Get-PrefsPcStep {
  param($Ctx, $Key)
  if ($Ctx.Pcs.Count -lt 2) { return 0 }
  if ($Key.Key -eq "LeftArrow") { return -1 }
  if ($Key.Key -eq "RightArrow") { return 1 }
  return 0
}

function Show-PrefsMenu {
  if (-not (Test-DriveConnected)) { return Get-ClmText "sync.prefs.needDrive" }
  $catalog = Read-SyncCatalog
  $me = Get-DrivePcName
  $ctx = @{ Catalog = $catalog; Choice = (Read-SyncChoice); Globals = (Get-GlobalNames @(Get-Accounts)); Me = $me; Pcs = (Get-PrefsPcs $catalog $me); At = 0 }
  $view = Get-PrefsView $ctx
  if ($view.Lines.Count -eq 0 -and $ctx.Pcs.Count -eq 1) { return Show-PrefsEmpty }
  $sel = Move-PrefsSel $view.Lines -1 1
  $changed = $false
  while ($true) {
    $k = Read-PageKey { Get-PageRows $view.Title (Get-PrefsBody $ctx $view $sel) $view.Pairs $view.Sub }
    if ($k.Key -eq "Escape" -or $k.KeyChar -eq "q") { break }
    $step = Get-PrefsPcStep $ctx $k
    if ($step -ne 0) {
      $ctx.At = ($ctx.At + $step + $ctx.Pcs.Count) % $ctx.Pcs.Count
      $view = Get-PrefsView $ctx
      $sel = Move-PrefsSel $view.Lines -1 1
      continue
    }
    if ($view.Lines.Count -eq 0) { continue }
    $prefsItem = $view.Lines[$sel]
    if ($k.Key -eq "UpArrow") { $sel = Move-PrefsSel $view.Lines $sel -1; continue }
    if ($k.Key -eq "DownArrow") { $sel = Move-PrefsSel $view.Lines $sel 1; continue }
    if (-not (Invoke-PrefsKey $ctx $k $prefsItem)) { continue }
    $changed = $true
    $view = Get-PrefsView $ctx
    if ($view.Lines.Count -eq 0 -and $ctx.Pcs.Count -eq 1) { break }
    $sel = Find-PrefsLine $view.Lines $prefsItem
  }
  if (-not $changed) { return Get-ClmText "sync.prefs.unchanged" }
  $null = Request-DriveSync $script:DriveJob
  return Get-ClmText "sync.prefs.saved"
}
