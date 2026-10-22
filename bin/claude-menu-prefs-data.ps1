$script:PrefsHomeLabel = "perso"
$script:PrefsGlobalTag = "ce PC"
$script:PrefsAllKey = "*"

function New-PrefsHead {
  param([string]$Text)
  return @{ Head = $true; Label = $Text }
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

function Get-SortedPrefsItems {
  param($Items)
  return ,@($Items | Sort-Object { $_.Label }, { $_.Tag })
}

function Add-SkillLines {
  param($Lines, $Choice, $Catalog)
  $names = New-NameSet @($Catalog.Skills, (Get-LocalSkillNames), $Choice.Erase.skills)
  $items = @(foreach ($n in $names) { New-PrefsItem "skills" $n $n "" (Test-SkillChecked $Choice $n) $Choice.Erase.skills.Contains($n) })
  Add-PrefsGroup $Lines "Skills" "skills" "tous les skills" $items
}

function Get-McpWhere {
  param([string]$Key, [string]$Os)
  $where = $script:PrefsHomeLabel
  $project = (Split-McpKey $Key).Project
  if ($project) { $where = @($project -split "/")[-1] }
  if ($Os) { $where += ", " + $Os }
  return $where
}

function New-McpItem {
  param([string]$Key, [string]$Os, [bool]$On, [bool]$Erasing)
  $item = New-PrefsItem "mcp" $Key (Split-McpKey $Key).Name (Get-McpWhere $Key $Os) $On $Erasing
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
    $items.Add((New-PrefsItem "globals" $n $n $script:PrefsGlobalTag (-not (Test-GlobalOff $Choice $n)) $Choice.Erase.globals.Contains($n)))
  }
  Add-PrefsGroup $Lines "MCP" "mcp" "tous les MCP" (Get-SortedPrefsItems $items)
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
