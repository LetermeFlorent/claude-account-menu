$textInvoke = (Get-Item "function:Invoke-ClaudeUpdate").ScriptBlock
$textWait = $script:ClaudeUpdateWaitMs
$textStampPath = Get-StatePath ($script:ClaudeCheckStamp + ".done")
$textAccounts = @(foreach ($l in @("a", "b")) { [PSCustomObject]@{ Label = $l; Dir = (".claude-" + $l) } })
$script:TextRuns = 0
function Invoke-ClaudeUpdate { param([string]$Exe, $Acc) $script:TextRuns++; return New-Outcome "updated" "Claude Code mis a jour, 2.1.290 -> 2.1.300" }

function Get-TextUpdateOutput {
  return ((@(& { Update-ClaudeForAccounts $textAccounts } 6>&1) | ForEach-Object { "" + $_ }) -join "`n")
}

try {
  if ([IO.File]::Exists($textStampPath)) { Remove-Item -LiteralPath $textStampPath -Force }
  $out = Get-TextUpdateOutput
  Assert-Equal 1 $script:TextRuns "mode texte, seul clm : Claude Code mis a jour une fois"
  Assert-Equal ("" + $PID + " Claude Code a jour (2.1.300)") ((Read-SharedText $textStampPath) -replace "^[0-9]+ ", "") "mode texte, seul clm : marque posee pour les autres clm"
  $again = Open-MachineLock $script:ClaudeUpdateLock
  Assert-True ($null -ne $again) "mode texte, seul clm : verrou rendu"
  Close-MachineLock $again

  Write-MachineStamp $script:ClaudeCheckStamp ("" + ($PID + 1) + " Claude Code a jour (2.1.300)")
  $script:TextRuns = 0
  $out = Get-TextUpdateOutput
  Assert-Equal 0 $script:TextRuns "mode texte, Claude Code verifie a l'instant par un autre clm : pas de mise a jour"
  Assert-True ($out -like "*a  *Claude Code a jour (2.1.300)*" -and $out -like "*b  *Claude Code a jour (2.1.300)*") "mode texte, Claude Code verifie a l'instant par un autre clm : a jour pour chaque compte"
  Remove-Item -LiteralPath $textStampPath -Force

  $script:ClaudeUpdateWaitMs = 600
  $held = Open-MachineLock $script:ClaudeUpdateLock
  try { $out = Get-TextUpdateOutput } finally { Close-MachineLock $held }
  Assert-Equal 0 $script:TextRuns "mode texte, autre clm bloque trop longtemps : pas de mise a jour en double"
  Assert-True ($out -like ("*" + $script:ClaudeWaitText + "*") -and $out -like ("*" + $script:ClaudeLeftText + "*")) "mode texte, autre clm bloque trop longtemps : attente puis main laissee"
  Assert-True ($out -notmatch "echec|impossible") "mode texte, autre clm bloque trop longtemps : aucune erreur"
} finally {
  Set-Item -Path "function:script:Invoke-ClaudeUpdate" -Value $textInvoke
  $script:ClaudeUpdateWaitMs = $textWait
  if ([IO.File]::Exists($textStampPath)) { Remove-Item -LiteralPath $textStampPath -Force }
}
