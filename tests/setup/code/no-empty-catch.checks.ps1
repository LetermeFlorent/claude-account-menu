$emptyRoot = Split-Path -Parent $bin
$emptyFiles = @(Get-ChildItem -LiteralPath $bin -Filter "*.ps1" -Recurse) + @(Get-ChildItem -LiteralPath $emptyRoot -Filter "*.ps1")
$emptyHits = New-Object Collections.Generic.List[string]
foreach ($emptyFile in $emptyFiles) {
  $emptyTokens = $null
  $emptyErrors = $null
  $emptyAst = [Management.Automation.Language.Parser]::ParseFile($emptyFile.FullName, [ref]$emptyTokens, [ref]$emptyErrors)
  $emptyFound = $emptyAst.FindAll({ param($n) $n -is [Management.Automation.Language.CatchClauseAst] -and $n.Body.Statements.Count -eq 0 }, $true)
  foreach ($c in $emptyFound) { $emptyHits.Add($emptyFile.Name + ":" + $c.Extent.StartLineNumber) }
}
Assert-Equal "" ($emptyHits -join " ") "aucun bloc catch vide dans bin et a la racine"
$analyzerSettings = [IO.File]::ReadAllText((Join-Path $emptyRoot "PSScriptAnalyzerSettings.psd1"))
Assert-True (-not $analyzerSettings.Contains("PSAvoidUsingEmptyCatchBlock")) "regle catch vide reactivee dans l'analyseur"
