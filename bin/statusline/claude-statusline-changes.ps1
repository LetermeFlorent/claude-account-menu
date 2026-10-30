if (-not (Test-Path Function:\Import-ClmModule)) { . (Join-Path $PSScriptRoot "../claude-import.ps1") }
. Import-ClmModule claude-file-io
$script:StatusChangesExt = ".changes"

function Read-StateFileLines {
  param([string]$Path)
  if (-not [IO.File]::Exists($Path)) { return @() }
  $lines = @((Read-SharedText $Path) -split "`r?`n")
  if ($lines[-1] -eq "") { $lines = @($lines | Select-Object -First ($lines.Count - 1)) }
  return $lines
}

function Get-StatusChanges {
  param([string]$State)
  $dir = Split-Path $State
  if (-not [IO.Directory]::Exists($dir)) { return @() }
  $prefix = (Split-Path $State -Leaf) + "."
  $names = [string[]]@([IO.Directory]::GetFiles($dir) | ForEach-Object { [IO.Path]::GetFileName($_) } | Where-Object {
      $_.Length -ge $prefix.Length + $script:StatusChangesExt.Length -and
      $_.StartsWith($prefix, [StringComparison]::Ordinal) -and $_.EndsWith($script:StatusChangesExt, [StringComparison]::Ordinal)
    })
  [Array]::Sort($names, [StringComparer]::Ordinal)
  return @($names | ForEach-Object { Join-Path $dir $_ })
}

function Set-StatusEntry {
  param($List, [string]$Entry)
  if ($Entry -eq "") { return }
  $i = $Entry.IndexOf(" ")
  $key = $Entry
  if ($i -ge 0) { $key = $Entry.Substring(0, $i) }
  $first = -1
  for ($n = $List.Count - 1; $n -ge 0; $n--) {
    if ($List[$n] -ceq $key -or $List[$n].StartsWith($key + " ", [StringComparison]::Ordinal)) { $List.RemoveAt($n); $first = $n }
  }
  if ($i -lt 0) { return }
  if ($first -lt 0) { $List.Add($Entry) } else { $List.Insert($first, $Entry) }
}

function Merge-StatusChanges {
  param([string[]]$Lines, [string[]]$Files, $Applied = $null)
  $list = New-Object Collections.Generic.List[string]
  foreach ($l in $Lines) { $list.Add($l) }
  foreach ($f in $Files) {
    try { $entries = @(Read-StateFileLines $f) } catch { Write-Verbose $_.Exception.Message; continue }
    foreach ($e in $entries) { Set-StatusEntry $list $e }
    if ($null -ne $Applied) { $Applied.Add($f) }
  }
  return $list.ToArray()
}

function Write-StatusChanges {
  param([string]$State, [string]$Id, [string[]]$Entries)
  Write-TextFileAtomic ($State + "." + $Id + $script:StatusChangesExt) (($Entries -join "`n") + "`n")
}

function Remove-StatusChanges {
  param([string[]]$Files)
  foreach ($f in $Files) {
    try { [IO.File]::Delete($f) } catch { Write-Verbose $_.Exception.Message }
  }
}
