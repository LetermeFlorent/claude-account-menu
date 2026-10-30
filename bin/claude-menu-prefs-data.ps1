. Import-ClmModule claude-text
$script:PrefsAllKey = "*"

function Get-PrefsThisPc {
  return Get-ClmText "sync.prefs.thisPc"
}

function Get-PrefsOffWarn {
  param([string]$Kind)
  return "  " + (Get-ClmText ("sync.prefs.off." + $Kind))
}

function Get-PrefsOffLines {
  param($Item, [string]$Pc = "")
  if (-not $Pc) { $Pc = Get-PrefsThisPc }
  $list = @($Item)
  if ($Item.All) { $list = @($Item.Items | Where-Object { $_.On }) }
  $lines = @(foreach ($k in @($list | ForEach-Object { $_.Kind } | Sort-Object -Unique)) { (Get-PrefsOffWarn $k).Replace((Get-PrefsThisPc), $Pc) })
  if ($Item.All) { $lines += "  " + (Get-ClmText "sync.prefs.manyOff" @($list.Count)) }
  return ,[string[]]$lines
}

function New-PrefsHead {
  param([string]$Text)
  return @{ Head = $true; Label = $Text }
}

function New-PrefsItem {
  param([hashtable]$Item)
  return @{ Head = $false; Kind = [string]$Item.Kind; Key = [string]$Item.Key; Label = [string]$Item.Label; Tag = [string]$Item.Tag; On = [bool]$Item.On; Erasing = [bool]$Item.Erasing }
}

function New-PrefsAll {
  param([string]$Kind, [string]$Label, $Items)
  $live = @($Items | Where-Object { -not $_.Head -and -not $_.Erasing })
  $on = @($live | Where-Object { $_.On }).Count
  $all = New-PrefsItem @{ Kind = $Kind; Key = $script:PrefsAllKey; Label = $Label; Tag = (Get-ClmText "sync.prefs.checkedCount" @($on, $live.Count)); On = ($live.Count -gt 0 -and $on -eq $live.Count); Erasing = $false }
  $all.All = $true
  $all.Mixed = $on -gt 0 -and $on -lt $live.Count
  $all.Items = $live
  return $all
}

function Add-PrefsGroup {
  param($Lines, [string]$Head, [string]$Kind, [string]$AllLabel, $Items)
  if ($Items.Count -eq 0) { return }
  $Lines.Add((New-PrefsHead $Head))
  $all = New-PrefsAll $Kind $AllLabel $Items
  if ($all.Items.Count -gt 0) { $Lines.Add($all) }
  foreach ($i in $Items) { $Lines.Add($i) }
}

function New-NameSet {
  param([object[]]$Parts)
  $set = New-Object 'System.Collections.Generic.SortedSet[string]' ([StringComparer]::Ordinal)
  foreach ($part in $Parts) { foreach ($n in @($part)) { if ($n) { [void]$set.Add([string]$n) } } }
  return ,$set
}

function Get-SortedPrefsItems {
  param($Items)
  return ,@($Items | Sort-Object { $_.Label }, { $_.Tag })
}

function Add-SkillLines {
  param($Lines, $Choice, $Catalog)
  $names = New-NameSet @($Catalog.Skills, (Get-LocalSkillNames), $Choice.Erase.skills)
  $items = @(foreach ($n in $names) { New-PrefsItem @{ Kind = "skills"; Key = $n; Label = $n; Tag = ""; On = (Test-SkillChecked $Choice $n); Erasing = $Choice.Erase.skills.Contains($n) } })
  Add-PrefsGroup $Lines (Get-ClmText "sync.prefs.head.skills") "skills" (Get-ClmText "sync.prefs.all.skills") $items
}

function Get-McpWhere {
  param([string]$Key, [string]$Os)
  $where = Get-ClmText "sync.prefs.home"
  $project = (Split-McpKey $Key).Project
  if ($project) { $where = @($project -split "/")[-1] }
  if ($Os) { $where += ", " + $Os }
  return $where
}

function New-McpItem {
  param([string]$Key, [string]$Os, [bool]$On, [bool]$Erasing)
  $item = New-PrefsItem @{ Kind = "mcp"; Key = $Key; Label = (Split-McpKey $Key).Name; Tag = (Get-McpWhere $Key $Os); On = $On; Erasing = $Erasing }
  $item.Os = $Os
  return $item
}

function Add-McpLines {
  param($Lines, $Choice, $Catalog, [string[]]$Globals)
  $effective = Get-McpCatalog $Catalog.Pcs
  $items = New-Object 'System.Collections.Generic.List[object]'
  foreach ($k in (New-NameSet @(@($effective.Keys), @($Choice.Erase.mcp)))) {
    if (-not (Test-McpKey $k)) { continue }
    $os = ""
    if ($null -ne $effective[$k]) { $os = $effective[$k].Os }
    $items.Add((New-McpItem $k $os (Test-McpChecked $Choice $k $os) $Choice.Erase.mcp.Contains($k)))
  }
  foreach ($n in (New-NameSet @($Globals, @($Catalog.Parked.Keys), $Choice.Erase.globals))) {
    $items.Add((New-PrefsItem @{ Kind = "globals"; Key = $n; Label = $n; Tag = (Get-PrefsThisPc); On = (-not (Test-GlobalOff $Choice $n)); Erasing = $Choice.Erase.globals.Contains($n) }))
  }
  Add-PrefsGroup $Lines (Get-ClmText "sync.prefs.head.mcp") "mcp" (Get-ClmText "sync.prefs.all.mcp") (Get-SortedPrefsItems $items)
}

function Get-PrefsLines {
  param($Choice, $Catalog, [string[]]$Globals)
  $lines = New-Object 'System.Collections.Generic.List[object]'
  Add-SkillLines $lines $Choice $Catalog
  Add-McpLines $lines $Choice $Catalog $Globals
  return ,$lines.ToArray()
}

function Set-PrefsState {
  param($Choice, $Item, [bool]$On)
  Remove-EraseRequests $Choice $Item.Kind @($Item.Key)
  $default = $true
  if ($Item.Kind -eq "mcp") { $default = $Item.Os -eq $script:OsName }
  Set-ChoiceCheck $Choice $Item.Kind $Item.Key $On $default
  Set-ChoiceStamp $Choice $Item.Kind $Item.Key
}

function Set-PrefsCheck {
  param($Choice, $Item)
  if ($Item.All) { foreach ($one in $Item.Items) { Set-PrefsState $Choice $one (-not $Item.On) }; return }
  if ($Item.Erasing) { Remove-EraseRequests $Choice $Item.Kind @($Item.Key); return }
  Set-PrefsState $Choice $Item (-not $Item.On)
}

function Get-GlobalNames {
  param($Accs)
  return ,[string[]]@((Get-GlobalDefs (Get-GlobalFiles $Accs @())).Keys)
}
