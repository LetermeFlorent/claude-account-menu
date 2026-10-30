. (Join-Path $bin "ui/terminal/claude-console-utf8.ps1")
$utf8Tokens = $null
$utf8Errors = $null
$utf8Ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $bin "claude-menu.ps1"), [ref]$utf8Tokens, [ref]$utf8Errors)
$utf8Tries = @($utf8Ast.FindAll({ param($n) $n -is [Management.Automation.Language.TryStatementAst] -and $null -ne $n.Finally -and $n.Finally.Extent.Text -match "Restore-ConsoleEncoding" }, $false))
Assert-Equal 1 $utf8Tries.Count "console utf-8 : la sortie du menu rend l'ancien encodage dans un finally"
Assert-True ($utf8Tries[0].Body.Extent.Text -match "Start-Account") "console utf-8 : le finally entoure tout le corps du menu"

$utf8InBefore = [Console]::InputEncoding.CodePage
$utf8Out = [Console]::OutputEncoding.CodePage
$utf8Kept = Use-ConsoleUtf8
if (Test-ConsoleUtf8Needed) {
  Assert-True ($null -ne $utf8Kept) "console utf-8 : Windows PowerShell 5.1 garde l'encodage precedent"
} else {
  Assert-Null $utf8Kept "console utf-8 : hors Windows PowerShell 5.1 rien n'est change"
}
Assert-Equal $utf8InBefore ([Console]::InputEncoding.CodePage) "console utf-8 : l'encodage de lecture des touches ne bouge pas"
Restore-ConsoleEncoding $utf8Kept
Assert-Equal $utf8Out ([Console]::OutputEncoding.CodePage) "console utf-8 : l'encodage de sortie est remis"
Restore-ConsoleEncoding $null
Assert-Equal $utf8Out ([Console]::OutputEncoding.CodePage) "console utf-8 : rien a remettre, rien ne change"

$utf8ConIn = Get-Content -LiteralPath (Join-Path $bin "ui/terminal/claude-ui-conin.ps1") -Raw
Assert-True ($utf8ConIn.Contains("ReadConsoleInputW") -and $utf8ConIn.Contains("PeekConsoleInputW")) "console utf-8 : touches et souris lues en unicode, hors page de code"
