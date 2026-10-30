. Import-ClmModule claude-text
$script:PrefsSideKeys = [string][char]0x2190 + [string][char]0x2192

function Get-PrefsPairs {
  return @((Get-ClmText "sync.prefs.key.space"), (Get-ClmText "sync.prefs.key.check"), (Get-ClmText "sync.prefs.key.delete"), (Get-ClmText "sync.prefs.key.eraseEverywhere"), (Get-ClmText "sync.prefs.key.escape"), (Get-ClmText "sync.prefs.key.back"))
}

function Get-PrefsPcPairs {
  return @((Get-ClmText "sync.prefs.key.space"), (Get-ClmText "sync.prefs.key.check"), (Get-ClmText "sync.prefs.key.escape"), (Get-ClmText "sync.prefs.key.back"))
}

function Get-PrefsPcs {
  param($Catalog, [string]$Me)
  if ($null -eq $Catalog.Pcs) { return ,[string[]]@($Me) }
  $names = [string[]]@($Catalog.Pcs.Keys | Where-Object { $_ -cne $Me })
  [Array]::Sort($names, [StringComparer]::OrdinalIgnoreCase)
  return ,[string[]]@(@($Me) + $names)
}

function Test-PcReachable {
  param($Catalog, [string]$Pc)
  return $null -ne $Catalog.Pcs -and $null -ne $Catalog.Pcs[$Pc] -and [bool]$Catalog.Pcs[$Pc].Os
}

function New-PcPrefsItem {
  param([hashtable]$Request)
  $kind = $Request.Kind
  $key = $Request.Key
  $base = [bool]$Request.Default
  if ($Request.Target.Choice[$kind].ContainsKey($key)) { $base = [bool]$Request.Target.Choice[$kind][$key] }
  $other = $Request.Pending.Others[$kind][$key]
  if ($null -ne $other) { $base = $other.On }
  $mine = $Request.Pending.Mine[$kind][$key]
  $on = $base
  if ($null -ne $mine -and ($null -eq $other -or $mine.At -gt $other.At)) { $on = $mine.On }
  $item = New-PrefsItem @{ Kind = $kind; Key = $key; Label = $Request.Label; Tag = $Request.Tag; On = $on; Erasing = $false }
  $item.Base = $base
  $item.Wait = $null -ne $other -or $null -ne $mine
  return $item
}

function Add-PcMcpLines {
  param($Lines, $Target, $Pending, $Effective)
  $items = New-Object 'System.Collections.Generic.List[object]'
  foreach ($k in (New-NameSet @($Effective.Keys))) {
    if (-not (Test-McpKey $k)) { continue }
    $os = $Effective[$k].Os
    $item = New-PcPrefsItem @{ Kind = "mcp"; Key = $k; Label = (Split-McpKey $k).Name; Tag = (Get-McpWhere $k $os); Target = $Target; Pending = $Pending; Default = ($os -eq $Target.Os) }
    $item.Os = $os
    $items.Add($item)
  }
  Add-PrefsGroup $Lines (Get-ClmText "sync.prefs.head.mcp") "mcp" (Get-ClmText "sync.prefs.all.mcp") (Get-SortedPrefsItems $items)
}

function Get-PcPrefsLines {
  param($Choice, $Catalog, [string]$Me, [string]$Pc)
  $lines = New-Object 'System.Collections.Generic.List[object]'
  if (-not (Test-PcReachable $Catalog $Pc)) { return ,$lines.ToArray() }
  $target = $Catalog.Pcs[$Pc]
  $pending = Get-PcPending $Catalog.Pcs $Choice $Me $Pc
  $skills = @(foreach ($n in (New-NameSet @($Catalog.Skills))) { New-PcPrefsItem @{ Kind = "skills"; Key = $n; Label = $n; Tag = ""; Target = $target; Pending = $pending; Default = $true } })
  Add-PrefsGroup $lines (Get-ClmText "sync.prefs.head.skills") "skills" (Get-ClmText "sync.prefs.all.skills") $skills
  if ($Catalog.PerPc) { Add-PcMcpLines $lines $target $pending (Get-McpCatalog $Catalog.Pcs) }
  return ,$lines.ToArray()
}

function Set-PcPrefsCheck {
  param([hashtable]$Request)
  $pc = $Request.Pc
  $after = [long]$Request.Catalog.Pcs[$pc].Took[$Request.Me]
  $list = @($Request.Item)
  if ($Request.Item.All) { $list = @($Request.Item.Items) }
  foreach ($one in $list) {
    if ($Request.On -eq $one.Base) { Remove-PcAsk $Request.Choice $pc $one.Kind $one.Key }
    else { Add-PcAsk @{ Choice = $Request.Choice; Pc = $pc; Kind = $one.Kind; Name = $one.Key; On = $Request.On; After = $after } }
  }
}

function Get-PcPrefsSub {
  param($Catalog, [string]$Pc)
  if (-not (Test-PcReachable $Catalog $Pc)) { return Get-ClmText "sync.prefs.pc.old" }
  return Get-ClmText "sync.prefs.pc.sub"
}

function Get-PrefsView {
  param($Ctx)
  $pc = $Ctx.Pcs[$Ctx.At]
  if ($Ctx.At -eq 0) {
    $v = @{ Title = (Get-ClmText "sync.prefs.title"); Sub = (Get-PrefsSub $Ctx.Catalog); Pairs = (Get-PrefsPairs); Empty = (Get-ClmText "sync.prefs.pc.none"); Lines = (Get-PrefsLines $Ctx.Choice $Ctx.Catalog $Ctx.Globals) }
  } else {
    $v = @{ Title = (Get-ClmText "sync.prefs.pc.title" @($pc)); Sub = (Get-PcPrefsSub $Ctx.Catalog $pc); Pairs = (Get-PrefsPcPairs); Empty = ""; Lines = (Get-PcPrefsLines $Ctx.Choice $Ctx.Catalog $Ctx.Me $pc) }
    if (Test-PcReachable $Ctx.Catalog $pc) { $v.Empty = Get-ClmText "sync.prefs.pc.none" }
  }
  if ($Ctx.Pcs.Count -gt 1) { $v.Pairs = @($v.Pairs[0..1]) + @($script:PrefsSideKeys, (Get-ClmText "sync.prefs.key.otherPc")) + @($v.Pairs[2..($v.Pairs.Count - 1)]) }
  return $v
}

function Get-PrefsPcRow {
  param($Ctx)
  $r = New-Row
  $r.Add(@("  ", $script:Ink.Dim, $false))
  for ($i = 0; $i -lt $Ctx.Pcs.Count; $i++) {
    $label = $Ctx.Pcs[$i]
    if ($i -eq 0) { $label += " (" + (Get-PrefsThisPc) + ")" }
    $ink = $script:Ink.Dim
    if ($i -eq $Ctx.At) { $ink = $script:Ink.Text }
    $r.Add(@($label, $ink, ($i -eq $Ctx.At)))
    $r.Add(@("   ", $script:Ink.Dim, $false))
  }
  return ,$r
}

function Get-PrefsBody {
  param($Ctx, $View, [int]$Sel)
  $rows = New-Object 'System.Collections.Generic.List[object]'
  if ($Ctx.Pcs.Count -gt 1) {
    $rows.Add((Get-PrefsPcRow $Ctx))
    $rows.Add((New-Row))
  }
  if ($View.Lines.Count -gt 0) { foreach ($r in (Get-PrefsRows $View.Lines $Sel ($rows.Count))) { $rows.Add($r) } }
  elseif ($View.Empty) { $rows.Add((New-TextRow ("  " + $View.Empty) $script:Ink.Dim)) }
  return ,$rows
}
