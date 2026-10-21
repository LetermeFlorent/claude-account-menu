. (Join-Path $PSScriptRoot "claude-menu-prefs-data.ps1")
$script:PrefsTitle = "Reglages de synchro de ce PC"
$script:PrefsPairs = @("Espace", "cocher", "Suppr", "effacer partout", "Echap", "revenir")
$script:PrefsChrome = 14
$script:PrefsLabelWidth = 34
$script:PrefsEraseWarn = @{
  skills = "  Le skill part a la corbeille du Drive et son dossier quitte chaque PC."
  mcp = "  Le MCP quitte chaque PC a sa prochaine synchro."
  globals = "  Le MCP quitte tous les comptes de ce PC et sa definition est oubliee."
}

function Get-PrefsSub {
  param($Catalog)
  if (@($Catalog.Waiting).Count -gt 0) { return "MCP envoyes en entier tant que ces PC n'ont pas clm a jour : " + (@($Catalog.Waiting) -join ", ") }
  if (-not $Catalog.PerPc) { return "MCP reglables par PC apres la prochaine synchro Drive" }
  return "case cochee : synchronise sur ce PC"
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
  if ($Item.Erasing) { $r.Add(@("  efface a la prochaine synchro", $script:Ink.Alert, $false)) }
  if ($Sel) { Add-MarkSeg $r }
  return ,$r
}

function Get-PrefsWindow {
  param([int]$Count, [int]$Sel)
  $max = [math]::Max(4, $script:UiRows - $script:PrefsChrome)
  if ($Count -le $max) { return @(0, $Count) }
  $start = [math]::Max(0, [math]::Min($Sel - [int]($max / 2), $Count - $max))
  return @($start, ($start + $max))
}

function Get-PrefsRows {
  param($Lines, [int]$Sel)
  $rows = New-Object 'System.Collections.Generic.List[object]'
  $win = Get-PrefsWindow $Lines.Count $Sel
  if ($win[0] -gt 0) { $rows.Add((New-TextRow ("    " + $script:UpArrow) $script:Ink.Dim)) }
  for ($i = $win[0]; $i -lt $win[1]; $i++) {
    $l = $Lines[$i]
    if ($l.Sub) { $rows.Add((New-TextRow ("    " + $l.Label) $script:Ink.Dim)) }
    elseif ($l.Head) { $rows.Add((New-TextRow ("  " + $l.Label) $script:Ink.Text $true)) }
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

function Confirm-PrefsErase {
  param($Item)
  $ask = "Effacer " + $Item.Label + " partout ?"
  $body = @(, (New-TextRow $script:PrefsEraseWarn[$Item.Kind] $script:Ink.Dim))
  $k = Read-PageKey { Get-PageRows $ask $body @("o", "confirmer", "autre touche", "annuler") }
  return $k.KeyChar -eq "o"
}

function Show-PrefsEmpty {
  $body = @(, (New-TextRow "  Rien a regler pour l'instant. Touche quelconque pour revenir." $script:Ink.Dim))
  $null = Read-PageKey { Get-PageRows $script:PrefsTitle $body @() }
  return "aucun reglage de synchro a montrer"
}

function Show-PrefsMenu {
  if (-not (Test-DriveConnected)) { return "reglages de synchro : connecte d'abord le Drive avec y" }
  $catalog = Read-SyncCatalog
  $prefsChoice = Read-SyncChoice
  $globals = Get-GlobalNames @(Get-Accounts)
  $lines = Get-PrefsLines $prefsChoice $catalog $globals
  if ($lines.Count -eq 0) { return Show-PrefsEmpty }
  $sel = Move-PrefsSel $lines -1 1
  $changed = $false
  while ($true) {
    $k = Read-PageKey { Get-PageRows $script:PrefsTitle (Get-PrefsRows $lines $sel) $script:PrefsPairs (Get-PrefsSub $catalog) }
    $prefsItem = $lines[$sel]
    if ($k.Key -eq "UpArrow") { $sel = Move-PrefsSel $lines $sel -1; continue }
    if ($k.Key -eq "DownArrow") { $sel = Move-PrefsSel $lines $sel 1; continue }
    if ($k.Key -eq "Escape" -or $k.KeyChar -eq "q") { break }
    if ($k.Key -eq "Spacebar") { $prefsChoice = Update-SyncChoice { param($c) Set-PrefsCheck $c $prefsItem } }
    elseif ($k.Key -eq "Delete" -and -not $prefsItem.Erasing -and -not $prefsItem.All -and (Confirm-PrefsErase $prefsItem)) { $prefsChoice = Update-SyncChoice { param($c) Add-EraseRequest $c $prefsItem.Kind $prefsItem.Key } }
    else { continue }
    $changed = $true
    $lines = Get-PrefsLines $prefsChoice $catalog $globals
    if ($lines.Count -eq 0) { break }
    $sel = Find-PrefsLine $lines $prefsItem
  }
  if (-not $changed) { return "reglages de synchro inchanges" }
  $null = Request-DriveSync $script:DriveJob
  return "reglages de synchro enregistres, synchro Drive lancee"
}
