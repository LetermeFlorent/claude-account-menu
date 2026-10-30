. (Join-Path (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "menu/startup") "startup-fakes.ps1")
$claudeWait = $script:ClaudeUpdateWaitMs
$claudeStampPath = Get-StatePath ($script:ClaudeCheckStamp + ".done")

function Write-PeerClaudeStamp {
  param([string]$Text)
  Write-MachineStamp $script:ClaudeCheckStamp ("" + ($PID + 1) + " " + $Text)
}

function Remove-ClaudeStamp {
  if ([IO.File]::Exists($claudeStampPath)) { Remove-Item -LiteralPath $claudeStampPath -Force }
}

try {
  Assert-Equal "claude-menu-startup-claude.ps1" (Split-Path -Leaf (Get-Item "function:Step-ClaudeStartup").ScriptBlock.File) "etape Claude Code : dans son propre fichier"

  Remove-ClaudeStamp
  New-StartupCase @("claude")
  $held = Open-MachineLock $script:ClaudeUpdateLock
  try {
    $null = Invoke-StartupTicks 3
    Assert-Equal 0 $script:ClaudeStarts "autre clm qui met a jour Claude Code : pas de mise a jour en double"
    Assert-Equal ("lock|" + (Get-ClmText "update.startup.waitOther")) ($script:Su.Steps[0].State + "|" + $script:Su.Steps[0].Text) "autre clm qui met a jour Claude Code : attente affichee"
    Assert-Equal "quit" (Send-StartupAct "quit").Name "autre clm qui met a jour Claude Code : arret sans attendre"
  } finally { Close-MachineLock $held }
  $null = Invoke-StartupTicks 6
  Assert-Equal 1 $script:ClaudeStarts "verrou rendu : Claude Code mis a jour par ce clm"
  Assert-Equal ("ok " + ((Get-ClmText "update.claude.upToDateVersion" @("2.1.292")) -replace "^Claude Code ", "")) ($script:Su.Steps[0].Kind + " " + $script:Su.Steps[0].Text) "verrou rendu : a jour"
  $again = Open-MachineLock $script:ClaudeUpdateLock
  Assert-True ($null -ne $again) "verrou rendu : libre a la fin"
  Close-MachineLock $again
  Assert-Equal ("" + $PID + " 2.1.292") ((Read-SharedText $claudeStampPath) -replace "^[0-9]+ ", "") "verification finie : marque posee pour les autres clm"

  New-StartupCase @("claude")
  $null = Invoke-StartupTicks 6
  Assert-Equal 1 $script:ClaudeStarts "marque posee par ce meme clm : verification refaite"

  Write-PeerClaudeStamp "2.1.300"
  New-StartupCase @("claude")
  $null = Invoke-StartupTicks
  Assert-Equal 0 $script:ClaudeStarts "Claude Code verifie a l'instant par un autre clm : pas de mise a jour"
  Assert-Equal ("done ok " + ((Get-ClmText "update.claude.upToDateVersion" @("2.1.300")) -replace "^Claude Code ", "")) ($script:Su.Steps[0].State + " " + $script:Su.Steps[0].Kind + " " + $script:Su.Steps[0].Text) "Claude Code verifie a l'instant par un autre clm : a jour"
  Assert-Equal ("  a, b, c : " + (Get-ClmText "update.claude.upToDateVersion" @("2.1.300"))) $script:St.Msg[0] "Claude Code verifie a l'instant par un autre clm : resultat sous les comptes"
  Remove-ClaudeStamp

  $script:ClaudeUpdateWaitMs = 1000
  New-StartupCase @("claude")
  $held = Open-MachineLock $script:ClaudeUpdateLock
  try { $null = Invoke-StartupTicks 6 } finally { Close-MachineLock $held }
  Assert-Equal ("done ok " + (Get-ClmText "update.startup.leftToOther")) ($script:Su.Steps[0].State + " " + $script:Su.Steps[0].Kind + " " + $script:Su.Steps[0].Text) "autre clm bloque trop longtemps : Claude Code laisse, sans erreur"
  Assert-Equal "0 " ("" + $script:ClaudeStarts + " " + $script:St.Msg[0]) "autre clm bloque trop longtemps : aucun message"
  $script:ClaudeUpdateWaitMs = $claudeWait

  $script:FakeClaudeFail = "echec de claude update (code 1)"
  New-StartupCase @("claude")
  $null = Invoke-StartupTicks 6
  Assert-True (-not [IO.File]::Exists($claudeStampPath)) "Claude Code en echec : aucune marque pour les autres clm"
} finally {
  $script:ClaudeUpdateWaitMs = $claudeWait
  Remove-ClaudeStamp
  Restore-StartupFakes
}
