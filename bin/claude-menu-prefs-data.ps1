$script:PrefsHomeLabel = "dossier perso"

function New-PrefsHead {
  param([string]$Text)
  return @{ Head = $true; Label = $Text }
}

function New-PrefsItem {
  param([string]$Kind, [string]$Key, [string]$Label, [string]$Tag, [bool]$On, [bool]$Erasing)
  return @{ Head = $false; Kind = $Kind; Key = $Key; Label = $Label; Tag = $Tag; On = $On; Erasing = $Erasing }
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
  foreach ($p in $groups.Keys) {
    $where = $p
    if (-not $p) { $where = $script:PrefsHomeLabel }
    $Lines.Add((New-PrefsHead ("MCP locaux : " + $where)))
    foreach ($k in $groups[$p]) {
      $os = ""
      if ($null -ne $effective[$k]) { $os = $effective[$k].Os }
      $Lines.Add((New-PrefsItem "mcp" $k (Split-McpKey $k).Name $os (Test-McpChecked $Choice $k $os) $Choice.Erase.mcp.Contains($k)))
    }
  }
}

function Add-GlobalLines {
  param($Lines, $Choice, $Catalog, [string[]]$Present)
  $names = New-NameSet @($Present, @($Catalog.Parked.Keys), $Choice.Erase.globals)
  if ($names.Count -eq 0) { return }
  $Lines.Add((New-PrefsHead "MCP globaux de ce PC, jamais envoyes aux autres PC"))
  foreach ($n in $names) { $Lines.Add((New-PrefsItem "globals" $n $n "" (-not (Test-GlobalOff $Choice $n)) $Choice.Erase.globals.Contains($n))) }
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
}

function Set-PrefsCheck {
  param($Choice, $Item)
  if ($Item.Erasing) { Remove-EraseRequests $Choice $Item.Kind @($Item.Key); return }
  Set-PrefsState $Choice $Item (-not $Item.On)
}

function Get-GlobalNames {
  param($Accs)
  return ,[string[]]@((Get-GlobalDefs (Get-GlobalFiles $Accs @())).Keys)
}
