Assert-Equal "claude" (Get-StateTag "/home/u/.claude") "tag .claude"
Assert-Equal "claude-compte2" (Get-StateTag "C:\Users\u\.claude-compte2") "tag .claude-compte2"
Assert-Equal "claude_work" (Get-StateTag "/home/u/.Claude Work/") "tag avec majuscule, espace et slash final"
Assert-Equal "claude-compte3" (Get-StateTag "C:\Users\u\.claude-compte3\\") "tag avec antislash final"
Assert-Equal "claude" (Get-StateTag "/home/u/...") "tag vide apres les points"
Assert-Equal "claude" (Get-StateTag "") "tag sans dossier"
Assert-Equal "compt_" (Get-StateTag ("/x/Compt" + [char]0x00E9)) "tag, lettre accentuee remplacee"
Assert-Equal "a_b" (Get-StateTag ("/x/a" + [char]0xD83D + [char]0xDE00 + "b")) "tag, caractere hors BMP compte pour un"

function Get-CompteUsage {
  param($Acc)
  return [PSCustomObject]@{ Error = $null; Pct5 = 42; Reset5 = "2030-01-01T00:00:00Z"; Pct7 = 7; Reset7 = "2030-01-03T00:00:00Z" }
}

$statePath = Get-StatusStatePath
New-Item -ItemType Directory -Force -Path (Split-Path $statePath) | Out-Null
$before = @("theme dark", "q5_at 1", "q5_pct 99", "q_at 5", "q7_at@claude 1", "q7_pct@claude 1", "q5_at@claude-compte2 111", "q_at@claude-compte2 222", "q5_at@claudex 3")
[IO.File]::WriteAllText($statePath, (($before -join "`n") + "`n"), (New-Object Text.UTF8Encoding($false)))
Update-StatusState ([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" })
$raw = [IO.File]::ReadAllText($statePath)
$lines = @($raw.TrimEnd("`n").Split("`n"))
Assert-True (-not $raw.Contains("`r")) "etat en LF"
Assert-True ([IO.File]::ReadAllBytes($statePath)[0] -ne 0xEF) "etat sans BOM"
Assert-True ($lines -contains "theme dark") "ligne etrangere conservee"
Assert-True ($lines -contains "q5_at@claude-compte2 111") "cle d'un autre compte conservee"
Assert-True ($lines -contains "q_at@claude-compte2 222") "q_at d'un autre compte conserve"
Assert-True ($lines -contains "q5_at@claudex 3") "tag voisin conserve"
Assert-Equal 0 @($lines | Where-Object { $_ -match "^(q5_at|q5_pct|q7_at|q7_pct|q_at) " }).Count "anciennes cles sans suffixe supprimees"
Assert-True ($lines -contains "q5_at@claude 1893456000") "q5_at du compte"
Assert-True ($lines -contains "q5_pct@claude 42") "q5_pct du compte"
Assert-True ($lines -contains "q7_at@claude 1893628800") "q7_at du compte remplace"
Assert-True ($lines -contains "q7_pct@claude 7") "q7_pct du compte remplace"
Assert-Equal 1 @($lines | Where-Object { $_ -match "^q_at@claude \d+$" }).Count "un seul q_at pour le compte"
Assert-Equal 1 @($lines | Where-Object { $_ -match "^q7_at@claude " }).Count "pas de doublon q7_at"
Update-StatusState ([PSCustomObject]@{ Label = "pro"; Dir = ".claude-compte2" })
$lines = @([IO.File]::ReadAllText($statePath).TrimEnd("`n").Split("`n"))
Assert-True ($lines -contains "q5_pct@claude-compte2 42") "second compte ecrit sous son tag"
Assert-True (-not ($lines -contains "q5_at@claude-compte2 111")) "ancienne valeur du second compte remplacee"
Assert-True ($lines -contains "q5_pct@claude 42") "premier compte intact"
