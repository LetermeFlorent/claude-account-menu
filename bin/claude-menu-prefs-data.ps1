$script:PrefsHomeLabel = "dossier perso"
$script:PrefsAllKey = "*"

function New-PrefsHead {
  param([string]$Text, [bool]$Sub = $false)
  return @{ Head = $true; Sub = $Sub; Label = $Text }
}

function New-PrefsItem {
  param([string]$Kind, [string]$Key, [string]$Label, [string]$Tag, [bool]$On, [bool]$Erasing)
  return @{ Head = $false; Kind = $Kind; Key = $Key; Label = $Label; Tag = $Tag; On = $On; Erasing = $Erasing }
}

function New-PrefsAll {
  param([string]$Kind, [string]$Label, $Items)
  $live = @($Items | Where-Object { -not $_.Head -and -not $_.Erasing })
  $on = @($live | Where-Object { $_.On }).Count
  $all = New-PrefsItem $Kind $script:PrefsAllKey $Label ("coches : " + $on + " sur " + $live.Count) ($live.Count -gt 0 -and $on -eq $live.Count) $false
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

function Add-SkillLines {
  param($Lines, $Choice, $Catalog)
  $names = New-NameSet @($Catalog.Skills, (Get-LocalSkillNames), $Choice.Erase.skills)
  if ($names.Count -eq 0) { return }
  $Lines.Add((New-PrefsHead "Skills"))
  foreach ($n in $names) { $Lines.Add((New-PrefsItem "skills" $n $n "" (Test-SkillChecked $Choice $n) $Choice.Erase.skills.Contains($n))) }
}

function Get-McpGroups {
  param($Effective, $Choice)
  $groups = New-Object 'System.Collections.Generic.SortedDictionary[string,object]' ([StringComparer]::OrdinalIgnoreCase)
  foreach ($k in @(@($Effective.Keys) + @($Choice.Erase.mcp))) {
    if (-not (Test-McpKey $k)) { continue }
    $p = (Split-McpKey $k).Project
    if (-not $groups.ContainsKey($p)) { $groups[$p] = New-NameSet }
    [void]$groups[$p].Add($k)
  }
  return ,$groups
}

function Add-McpLines {
  param($Lines, $Choice, $Catalog)
  $effective = Get-McpCatalog $Catalog.Pcs
  $groups = Get-McpGroups $effective $Choice
  $items = New-Object 'System.Collections.Generic.List[object]'
  foreach ($p in $groups.Keys) {
    $where = $p
    if (-not $p) { $where = $script:PrefsHomeLabel }
    $items.Add((New-PrefsHead $where $true))
    foreach ($k in $groups[$p]) {
      $os = ""
      if ($null -ne $effective[$k]) { $os = $effective[$k].Os }
      $items.Add((New-PrefsItem "mcp" $k (Split-McpKey $k).Name $os (Test-McpChecked $Choice $k $os) $Choice.Erase.mcp.Contains($k)))
    }
  }
  Add-PrefsGroup $Lines "MCP locaux" "mcp" "tous les MCP locaux" $items
}

function Add-GlobalLines {
  param($Lines, $Choice, $Catalog, [string[]]$Present)
  $names = New-NameSet @($Present, @($Catalog.Parked.Keys), $Choice.Erase.globals)
  $items = @(foreach ($n in $names) { New-PrefsItem "globals" $n $n "" (-not (Test-GlobalOff $Choice $n)) $Choice.Erase.globals.Contains($n) })
  Add-PrefsGroup $Lines "MCP globaux de ce PC, jamais envoyes aux autres PC" "globals" "tous les MCP globaux" $items
}

function Get-PrefsLines {
  param($Choice, $Catalog, [string[]]$Globals)
  $lines = New-Object 'System.Collections.Generic.List[object]'
  Add-SkillLines $lines $Choice $Catalog
  Add-McpLines $lines $Choice $Catalog
  Add-GlobalLines $lines $Choice $Catalog $Globals
  return ,$lines.ToArray()
}

function Set-PrefsState {
  param($Choice, $Item, [bool]$On)
  Remove-EraseRequests $Choice $Item.Kind @($Item.Key)
  $default = $true
  if ($Item.Kind -eq "mcp") { $default = $Item.Tag -eq $script:OsName }
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
