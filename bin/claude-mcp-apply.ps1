if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-drive-mcp.ps1")) { . (Join-Path $PSScriptRoot "claude-drive-mcp.ps1") }
$script:McpHomeFile = ".mcp.json"

function Get-McpFiles {
  param($Accs, [string[]]$Held)
  $out = New-Object 'System.Collections.Generic.List[object]'
  foreach ($a in $Accs) {
    $rel = Get-HeldPath $a.Dir
    $out.Add(@{ Rel = $rel; Home = $false; Held = ($Held -contains $rel) })
  }
  $out.Add(@{ Rel = $script:McpHomeFile; Home = $true; Held = $false })
  foreach ($f in $out) { Read-McpState $f }
  return ,$out.ToArray()
}

function Add-McpKeyProject {
  param($Map)
  if ($null -eq $Map) { return $null }
  $out = New-PathMap
  foreach ($n in $Map.Keys) { $out[(Join-McpKey "" $n)] = $Map[$n] }
  return $out
}

function Get-McpNamesOnly {
  param($Map)
  $out = New-PathMap
  foreach ($k in $Map.Keys) { $out[(Split-McpKey $k).Name] = $Map[$k] }
  return $out
}

function Read-McpState {
  param($File)
  $File.Path = Get-SyncLocalPath $File.Rel
  $File.Exists = [IO.File]::Exists($File.Path)
  $File.Map = $null
  if (-not $File.Exists) {
    if ($File.Home) { $File.Map = New-PathMap }
    return
  }
  try { $text = [IO.File]::ReadAllText($File.Path) } catch { Write-Verbose $_.Exception.Message; return }
  if ($File.Home) { $File.Map = Add-McpKeyProject (Read-McpMap $text) }
  else { $File.Map = Read-ProjectMcp $text }
}

function Test-McpPublishable {
  param([string]$Key, [string]$Def)
  return (Test-McpKey $Key) -and $Def.Length -le $script:McpDefMax
}

function Update-McpFromFile {
  param($File, $Catalog, [string]$Pc, $Checks, $Choice)
  $base = $Catalog.Applied[$File.Rel]
  $known = Get-McpCatalog $Catalog.Pcs -WithDeleted
  foreach ($k in $File.Map.Keys) {
    $def = $File.Map[$k]
    if (-not (Test-McpPublishable $k $def)) { continue }
    if ($null -eq $base) {
      if ($Choice.mcp.ContainsKey($k)) { continue }
      if ($null -eq $known[$k]) { Publish-McpEntry $Catalog $Pc $k $def }
      $Checks[$k] = $true
      continue
    }
    if ($base.ContainsKey($k) -and $base[$k] -ceq $def) { continue }
    Publish-McpEntry $Catalog $Pc $k $def
    $Checks[$k] = $true
  }
  if ($null -eq $base) { return }
  foreach ($k in $base.Keys) { if (-not $File.Map.ContainsKey($k) -and -not $Checks.ContainsKey($k)) { $Checks[$k] = $false } }
}

function Set-McpChecks {
  param($Choice, $Checks, $Effective)
  foreach ($k in $Checks.Keys) {
    $default = $true
    if ($null -ne $Effective[$k]) { $default = $Effective[$k].Os -eq $script:OsName }
    Set-ChoiceCheck $Choice "mcp" $k $Checks[$k] $default
  }
}

function Test-McpWanted {
  param($File, [string]$Project, $Present)
  if ($File.Home) { return $Project -eq "" }
  if ($Project -eq "") { return $false }
  return $null -ne $Present[$Project] -or [IO.Directory]::Exists((Get-SyncLocalPath $Project))
}

function Get-McpDesired {
  param($Effective, $Choice, $File)
  $map = New-PathMap
  $present = Group-McpByProject $File.Map
  foreach ($k in $Effective.Keys) {
    $e = $Effective[$k]
    if ((Test-McpChecked $Choice $k $e.Os) -and (Test-McpWanted $File (Split-McpKey $k).Project $present)) { $map[$k] = $e.Def }
  }
  foreach ($k in $File.Map.Keys) { if (-not (Test-McpPublishable $k $File.Map[$k])) { $map[$k] = $File.Map[$k] } }
  return $map
}

function Write-McpDesired {
  param($File, $Desired)
  if ($File.Home) { Write-McpFile $File.Path (Get-McpNamesOnly $Desired) }
  else { Write-ProjectMcpFile $File.Path $Desired }
}

function Sync-McpFile {
  param($File, $Desired, $Catalog)
  if ($File.Held -or (Test-McpMapEqual $File.Map $Desired) -or (-not $File.Exists -and $Desired.Count -eq 0)) {
    $Catalog.Applied[$File.Rel] = $File.Map
    return 0
  }
  try { Write-McpDesired $File $Desired } catch { Write-Verbose $_.Exception.Message; $Catalog.Applied[$File.Rel] = $File.Map; return 1 }
  $Catalog.Applied[$File.Rel] = $Desired
  return 0
}

function Use-ProjectCase {
  param($Catalog, $Files)
  $caseMap = New-ProjectCaseMap
  Add-ProjectCase $caseMap @((Get-McpCatalog $Catalog.Pcs -WithDeleted).Keys)
  foreach ($f in $Files) { if ($null -ne $f.Map) { Add-ProjectCase $caseMap @($f.Map.Keys) } }
  foreach ($f in $Files) { $f.Map = Convert-McpMapCase $caseMap $f.Map }
  foreach ($r in @($Catalog.Applied.Keys)) { $Catalog.Applied[$r] = Convert-McpMapCase $caseMap $Catalog.Applied[$r] }
  return $caseMap
}

function Sync-McpPrefs {
  param($Prefs, $Accs)
  $cat = $Prefs.Catalog
  $before = Get-OwnPcText $cat $Prefs.Pc
  $files = Get-McpFiles $Accs @(Get-HeldPaths)
  $caseMap = Use-ProjectCase $cat $files
  $mcpChecks = New-PathMap
  foreach ($f in $files) { if ($null -ne $f.Map) { Update-McpFromFile $f $cat $Prefs.Pc $mcpChecks $Prefs.Choice } }
  $mcpErase = [string[]]@($Prefs.Choice.Erase.mcp)
  foreach ($k in $mcpErase) { Remove-McpEverywhere $cat $Prefs.Pc $k }
  Save-OwnPcFile $Prefs $before
  $mcpEffective = Convert-McpMapCase $caseMap (Get-McpCatalog $cat.Pcs)
  $Prefs.Choice = Update-SyncChoice { param($c) Set-McpChecks $c $mcpChecks $mcpEffective; Remove-EraseRequests $c "mcp" $mcpErase }
  $failed = 0
  foreach ($f in $files) {
    if ($null -eq $f.Map) { if (-not $f.Exists) { $cat.Applied.Remove($f.Rel) }; continue }
    $failed += Sync-McpFile $f (Get-McpDesired $mcpEffective $Prefs.Choice $f) $cat
  }
  return $failed
}
