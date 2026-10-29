. (Join-Path $bin "claude-menu-select.ps1")
$textClearKept = Get-Item function:Clear-ConsoleInput -ErrorAction SilentlyContinue
$textAccountsKept = ${function:Get-Accounts}
$script:TextPrompts = New-Object 'System.Collections.Generic.List[string]'
function Clear-ConsoleInput { }
function Get-Accounts { return @() }
function Read-TextAnswer { param($Prompt) $script:TextPrompts.Add([string]$Prompt); return "1" }
Set-Alias -Name Read-Host -Value Read-TextAnswer
try {
  $textUsages = @(Get-AllUsages)
  Assert-Equal 0 $textUsages.Count "texte sans compte : aucune ligne de quota"
  $textErr = ""
  $textPick = "x"
  try { $textPick = Read-AccountNumber $textUsages } catch { $textErr = $_.Exception.Message }
  Assert-Equal "" $textErr "texte sans compte : choix d'un compte sans erreur"
  Assert-Null $textPick "texte sans compte : aucun compte choisi"
  $textErr = ""
  $textPick = "x"
  try { $textPick = Read-AccountNumber $null } catch { $textErr = $_.Exception.Message }
  Assert-Equal "" $textErr "texte liste absente : choix d'un compte sans erreur"
  Assert-Null $textPick "texte liste absente : aucun compte choisi"
} finally {
  Remove-Item -Path Alias:Read-Host, function:Read-TextAnswer
  if ($textClearKept) { Set-Item -Path function:Clear-ConsoleInput -Value $textClearKept.ScriptBlock } else { Remove-Item -Path function:Clear-ConsoleInput }
  ${function:Get-Accounts} = $textAccountsKept
}
