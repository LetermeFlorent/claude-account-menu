. Import-ClmModule claude-mcp-apply

function Get-GlobalFiles {
  param($Accs, [string[]]$Held)
  $out = New-Object 'System.Collections.Generic.List[object]'
  foreach ($a in $Accs) {
    $rel = Get-HeldPath $a.Dir
    $path = Get-SyncLocalPath $rel
    $map = $null
    try { $map = Read-McpFile $path } catch { Write-Verbose $_.Exception.Message }
    if ($null -ne $map) { $out.Add(@{ Path = $path; Held = ($Held -contains $rel); Map = $map }) }
  }
  return ,$out.ToArray()
}

function Get-GlobalDefs {
  param($Files)
  $defs = New-PathMap
  foreach ($f in $Files) { foreach ($n in $f.Map.Keys) { if (-not $defs.ContainsKey($n)) { $defs[$n] = $f.Map[$n] } } }
  return $defs
}

function Get-GlobalsAdded {
  param($Catalog, $Defs)
  if ($null -eq $Catalog.Globals) { return ,[string[]]@() }
  return ,[string[]]@($Defs.Keys | Where-Object { $Catalog.Globals -cnotcontains $_ })
}

function Get-GlobalRestore {
  param($Parked, $Defs)
  $out = New-PathMap
  foreach ($n in $Parked.Keys) {
    if ($Defs.ContainsKey($n)) { $out[$n] = $Defs[$n] } else { $out[$n] = $Parked[$n] }
  }
  return $out
}

function Update-GlobalFile {
  param($File, $Choice, $Restore)
  $map = New-PathMap
  foreach ($n in $File.Map.Keys) { if (-not (Test-GlobalOff $Choice $n)) { $map[$n] = $File.Map[$n] } }
  foreach ($n in $Restore.Keys) { if (-not (Test-GlobalOff $Choice $n) -and -not $map.ContainsKey($n)) { $map[$n] = $Restore[$n] } }
  if (Test-McpMapEqual $map $File.Map) { return 0 }
  try { Write-McpFile $File.Path $map } catch { Write-Verbose $_.Exception.Message; return 1 }
  $File.Map = $map
  return 0
}

function Update-ParkedGlobals {
  param($Catalog, $Choice, $Defs)
  foreach ($n in $Defs.Keys) { if ((Test-GlobalOff $Choice $n) -and -not $Choice.Erase.globals.Contains($n)) { $Catalog.Parked[$n] = $Defs[$n] } }
  foreach ($n in $Choice.Erase.globals) { $Catalog.Parked.Remove($n) }
}

function Remove-RestoredGlobals {
  param($Catalog, $Choice, $Files)
  $open = @($Files | Where-Object { -not $_.Held })
  if ($open.Count -eq 0) { return }
  foreach ($n in @($Catalog.Parked.Keys)) {
    if (Test-GlobalOff $Choice $n) { continue }
    if (@($open | Where-Object { -not $_.Map.ContainsKey($n) }).Count -eq 0) { $Catalog.Parked.Remove($n) }
  }
}

function Sync-GlobalMcp {
  param($Prefs, $Accs)
  $cat = $Prefs.Catalog
  $files = Get-GlobalFiles $Accs @(Get-HeldPaths)
  $defs = Get-GlobalDefs $files
  $globalsAdded = Get-GlobalsAdded $cat $defs
  if ($globalsAdded.Count -gt 0) { $Prefs.Choice = Update-SyncChoice { param($c) foreach ($n in $globalsAdded) { $null = $c.globals.Remove($n) } } }
  Update-ParkedGlobals $cat $Prefs.Choice $defs
  $restore = Get-GlobalRestore $cat.Parked $defs
  $failed = 0
  foreach ($f in $files) { if (-not $f.Held) { $failed += Update-GlobalFile $f $Prefs.Choice $restore } }
  Remove-RestoredGlobals $cat $Prefs.Choice $files
  $present = Get-GlobalDefs $files
  $cat.Globals = [string[]]@($present.Keys)
  $globalsDone = [string[]]@($Prefs.Choice.Erase.globals | Where-Object { -not $present.ContainsKey($_) })
  if ($globalsDone.Count -gt 0) { $Prefs.Choice = Update-SyncChoice { param($c) Remove-EraseRequests $c "globals" $globalsDone } }
  return $failed
}
