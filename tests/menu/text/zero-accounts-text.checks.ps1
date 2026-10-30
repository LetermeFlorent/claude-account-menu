. (Join-Path $bin "menu/loop/claude-menu-select.ps1")
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
  $textShown = ""
  try {
    $textOut = @(Read-AccountNumber $textUsages 6>&1)
    $textPick = $textOut | Where-Object { $_ -isnot [Management.Automation.InformationRecord] } | Select-Object -First 1
    $textShown = (@($textOut | Where-Object { $_ -is [Management.Automation.InformationRecord] } | ForEach-Object { [string]$_.MessageData.Message }) -join "`n")
  } catch { $textErr = $_.Exception.Message }
  Assert-Equal "" $textErr "texte sans compte : choix d'un compte sans erreur"
  Assert-Null $textPick "texte sans compte : aucun compte choisi"
  Assert-Equal 0 $script:TextPrompts.Count "texte sans compte : aucune question posee"
  Assert-True (-not ($script:TextPrompts -match "1-0")) "texte sans compte : pas de question 1-0"
  Assert-True ($textShown.Contains((Get-ClmText "menu.select.noAccount"))) "texte sans compte : message clair affiche"
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
