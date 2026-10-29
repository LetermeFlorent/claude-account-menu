function Get-FnDuplicates {
  param($Sources)
  $seen = @{}
  foreach ($s in $Sources) {
    foreach ($d in $s.Ast.FindAll({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
      $key = $d.Name.ToLowerInvariant()
      if (-not $seen.ContainsKey($key)) { $seen[$key] = New-Object 'System.Collections.Generic.List[string]' }
      if (-not $seen[$key].Contains($s.Name)) { $seen[$key].Add($s.Name) }
    }
  }
  foreach ($k in ($seen.Keys | Sort-Object)) { if ($seen[$k].Count -gt 1) { $k + ": " + ($seen[$k] -join ", ") } }
}

$fnSources = foreach ($f in Get-ChildItem -LiteralPath $bin -Filter "*.ps1" | Sort-Object Name) {
  $fnTokens = $null; $fnErrors = $null
  [PSCustomObject]@{ Name = $f.Name; Ast = [Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$fnTokens, [ref]$fnErrors) }
}
Assert-Equal "" (@(Get-FnDuplicates $fnSources) -join " | ") "fonctions de bin : aucun nom defini dans deux fichiers"

$fnPair = foreach ($p in @(@("a.ps1", "function Get-Thing { 1 }"), @("b.ps1", "function outer { function GET-THING { 2 } }"), @("c.ps1", "function Other { 3 }"))) {
  $fnTokens = $null; $fnErrors = $null
  [PSCustomObject]@{ Name = $p[0]; Ast = [Management.Automation.Language.Parser]::ParseInput($p[1], [ref]$fnTokens, [ref]$fnErrors) }
}
Assert-Equal "get-thing: a.ps1, b.ps1" (@(Get-FnDuplicates $fnPair) -join " | ") "fonctions de bin : un nom defini dans deux fichiers est detecte"
