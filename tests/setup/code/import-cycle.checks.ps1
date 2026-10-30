$cycleGraph = @{}
foreach ($f in Get-ChildItem -LiteralPath $bin -Filter "claude-*.ps1" -Recurse) {
  $deps = New-Object 'System.Collections.Generic.List[string]'
  foreach ($line in [IO.File]::ReadAllLines($f.FullName)) {
    if ($line -match '^\. Import-ClmModule (.+)$') { foreach ($n in $Matches[1].Split(",")) { $deps.Add($n.Trim()) } }
  }
  $cycleGraph[$f.BaseName] = $deps
}

function Test-ImportCycle {
  param([string]$Start)
  $seen = New-Object 'System.Collections.Generic.HashSet[string]'
  $todo = New-Object 'System.Collections.Generic.Stack[string]'
  $todo.Push($Start)
  while ($todo.Count -gt 0) {
    foreach ($d in $cycleGraph[$todo.Pop()]) {
      if ($d -eq $Start) { return $true }
      if ($seen.Add($d) -and $cycleGraph.ContainsKey($d)) { $todo.Push($d) }
    }
  }
  return $false
}

$cycleFound = @($cycleGraph.Keys | Where-Object { Test-ImportCycle $_ } | Sort-Object)
Assert-Equal "" ($cycleFound -join " ") "modules : aucun module ne se recharge par ses imports"
