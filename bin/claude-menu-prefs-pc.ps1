$script:PrefsPcOld = "clm n'est pas a jour sur ce PC : ses reglages ne se changent pas d'ici"
$script:PrefsPcSub = "case cochee : synchronise sur ce PC, change a sa prochaine synchro"
$script:PrefsPcNone = "Rien a regler sur ce PC pour l'instant."
$script:PrefsPcWait = "en attente"
$script:PrefsPcTitle = "Reglages de synchro de "
$script:PrefsPcPairs = @("Espace", "cocher", "Echap", "revenir")
$script:PrefsSideKeys = [string][char]0x2190 + [string][char]0x2192

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
  param([string]$Kind, [string]$Key, [string]$Label, [string]$Tag, $Target, $Pending, [bool]$Default)
  $base = $Default
  if ($Target.Choice[$Kind].ContainsKey($Key)) { $base = [bool]$Target.Choice[$Kind][$Key] }
  $other = $Pending.Others[$Kind][$Key]
  if ($null -ne $other) { $base = $other.On }
  $mine = $Pending.Mine[$Kind][$Key]
  $on = $base
  if ($null -ne $mine -and ($null -eq $other -or $mine.At -gt $other.At)) { $on = $mine.On }
  $item = New-PrefsItem $Kind $Key $Label $Tag $on $false
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
    $item = New-PcPrefsItem "mcp" $k (Split-McpKey $k).Name (Get-McpWhere $k $os) $Target $Pending ($os -eq $Target.Os)
    $item.Os = $os
    $items.Add($item)
  }
  Add-PrefsGroup $Lines "MCP" "mcp" "tous les MCP" (Get-SortedPrefsItems $items)
}

function Get-PcPrefsLines {
  param($Choice, $Catalog, [string]$Me, [string]$Pc)
  $lines = New-Object 'System.Collections.Generic.List[object]'
  if (-not (Test-PcReachable $Catalog $Pc)) { return ,$lines.ToArray() }
  $target = $Catalog.Pcs[$Pc]
  $pending = Get-PcPending $Catalog.Pcs $Choice $Me $Pc
  $skills = @(foreach ($n in (New-NameSet @($Catalog.Skills))) { New-PcPrefsItem "skills" $n $n "" $target $pending $true })
  Add-PrefsGroup $lines "Skills" "skills" "tous les skills" $skills
  if ($Catalog.PerPc) { Add-PcMcpLines $lines $target $pending (Get-McpCatalog $Catalog.Pcs) }
  return ,$lines.ToArray()
}

function Set-PcPrefsCheck {
  param($Choice, $Catalog, [string]$Me, [string]$Pc, $Item, [bool]$On)
  $after = [long]$Catalog.Pcs[$Pc].Took[$Me]
  $list = @($Item)
  if ($Item.All) { $list = @($Item.Items) }
  foreach ($one in $list) {
    if ($On -eq $one.Base) { Remove-PcAsk $Choice $Pc $one.Kind $one.Key }
    else { Add-PcAsk $Choice $Pc $one.Kind $one.Key $On $after }
  }
}

function Get-PcPrefsSub {
  param($Catalog, [string]$Pc)
  if (-not (Test-PcReachable $Catalog $Pc)) { return $script:PrefsPcOld }
  return $script:PrefsPcSub
}

function Get-PrefsView {
  param($Ctx)
  $pc = $Ctx.Pcs[$Ctx.At]
  if ($Ctx.At -eq 0) {
    $v = @{ Title = $script:PrefsTitle; Sub = (Get-PrefsSub $Ctx.Catalog); Pairs = $script:PrefsPairs; Empty = $script:PrefsPcNone; Lines = (Get-PrefsLines $Ctx.Choice $Ctx.Catalog $Ctx.Globals) }
  } else {
    $v = @{ Title = ($script:PrefsPcTitle + $pc); Sub = (Get-PcPrefsSub $Ctx.Catalog $pc); Pairs = $script:PrefsPcPairs; Empty = ""; Lines = (Get-PcPrefsLines $Ctx.Choice $Ctx.Catalog $Ctx.Me $pc) }
    if (Test-PcReachable $Ctx.Catalog $pc) { $v.Empty = $script:PrefsPcNone }
  }
  if ($Ctx.Pcs.Count -gt 1) { $v.Pairs = @($v.Pairs[0..1]) + @($script:PrefsSideKeys, "autre PC") + @($v.Pairs[2..($v.Pairs.Count - 1)]) }
  return $v
}

function Get-PrefsPcRow {
  param($Ctx)
  $r = New-Row
  $r.Add(@("  ", $script:Ink.Dim, $false))
  for ($i = 0; $i -lt $Ctx.Pcs.Count; $i++) {
    $label = $Ctx.Pcs[$i]
    if ($i -eq 0) { $label += " (ce PC)" }
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
