. (Join-Path $PSScriptRoot "claude-sync-pcdata.ps1")
$script:SyncCatalogPath = Join-Path (Get-HomeDir) ".clm-sync-catalog.json"

function New-SyncCatalog {
  return @{ PerPc = $false; Waiting = [string[]]@(); Skills = [string[]]@(); Pcs = (New-PathMap); Applied = (New-PathMap); Parked = (New-PathMap); Globals = $null }
}

function Read-StringMap {
  param($Data)
  $map = New-PathMap
  foreach ($n in (Get-JsonKeys $Data)) { if ($Data[$n] -is [string]) { $map[[string]$n] = $Data[$n] } }
  return $map
}

function Read-SyncCatalog {
  $cat = New-SyncCatalog
  try { $data = Read-JsonFile $script:SyncCatalogPath } catch { $data = $null }
  if ($data -isnot [Collections.IDictionary]) { return $cat }
  $keys = Get-JsonKeys $data
  if ($keys -contains "perPc") { $cat.PerPc = $data["perPc"] -eq $true }
  if ($keys -contains "waiting") { $cat.Waiting = [string[]]@($data["waiting"] | Where-Object { $_ -is [string] -and $_ }) }
  if ($keys -contains "skills") { $cat.Skills = [string[]]@($data["skills"] | Where-Object { $_ -is [string] -and (Test-SkillName $_) }) }
  if ($keys -contains "globals") { $cat.Globals = [string[]]@($data["globals"] | Where-Object { $_ -is [string] -and $script:McpNamePattern.IsMatch($_) }) }
  if ($keys -contains "parked") { $cat.Parked = Read-StringMap $data["parked"] }
  if ($keys -contains "pcs") { foreach ($pc in (Get-JsonKeys $data["pcs"])) { $cat.Pcs[[string]$pc] = ConvertFrom-PcData $data["pcs"][$pc] $true } }
  if ($keys -notcontains "applied") { return $cat }
  foreach ($rel in (Get-JsonKeys $data["applied"])) { $cat.Applied[[string]$rel] = Read-StringMap $data["applied"][$rel] }
  return $cat
}

function Save-SyncCatalog {
  param($Catalog)
  $pcs = [ordered]@{}
  $sorted = ConvertTo-SortedMap $Catalog.Pcs
  foreach ($pc in $sorted.Keys) { $pcs[$pc] = ConvertTo-PcData $sorted[$pc] -WithMd5 }
  $applied = [ordered]@{}
  $sorted = ConvertTo-SortedMap $Catalog.Applied
  foreach ($rel in $sorted.Keys) { $applied[$rel] = ConvertTo-SortedMap $sorted[$rel] }
  $data = [ordered]@{ perPc = [bool]$Catalog.PerPc; waiting = [string[]]$Catalog.Waiting; skills = [string[]]$Catalog.Skills; pcs = $pcs; applied = $applied; parked = (ConvertTo-SortedMap $Catalog.Parked) }
  if ($null -ne $Catalog.Globals) { $data.globals = [string[]]$Catalog.Globals }
  Write-TextFileAtomic $script:SyncCatalogPath ((ConvertTo-JsonText $data) + "`n")
  if ($script:OsName -ne "Windows") { try { & chmod 600 $script:SyncCatalogPath } catch { Write-Verbose $_.Exception.Message } }
}

function Get-McpCatalog {
  param($Pcs, [switch]$WithDeleted)
  $best = New-PathMap
  $names = [string[]]@($Pcs.Keys)
  [Array]::Sort($names, [StringComparer]::Ordinal)
  foreach ($pc in $names) {
    foreach ($k in $Pcs[$pc].Mcp.Keys) {
      $e = $Pcs[$pc].Mcp[$k]
      $cur = $best[$k]
      if ($null -eq $cur -or $e.At -gt $cur.At -or ($e.At -eq $cur.At -and ($e.Deleted -or -not $cur.Deleted))) { $best[$k] = $e }
    }
  }
  if ($WithDeleted) { return $best }
  foreach ($k in @($best.Keys)) { if ($best[$k].Deleted) { $best.Remove($k) } }
  return $best
}

function Get-ErasedSkills {
  param($Pcs)
  $out = New-PathMap
  foreach ($pc in $Pcs.Keys) { foreach ($n in $Pcs[$pc].Erased.Keys) { if ($Pcs[$pc].Erased[$n] -gt [long]$out[$n]) { $out[$n] = $Pcs[$pc].Erased[$n] } } }
  return $out
}
