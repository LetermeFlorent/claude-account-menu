$barPath = Get-StatusStatePath
New-Item -ItemType Directory -Force -Path (Split-Path $barPath) | Out-Null
$barNow = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$barKept = $null
if ([IO.File]::Exists($barPath)) { $barKept = [IO.File]::ReadAllBytes($barPath) }
$lines = @(("q_at@claude-bar " + ($barNow - 5)), ("q5_at@claude-bar " + ($barNow + 3600)), "q5_pct@claude-bar 11", ("q7_at@claude-bar " + ($barNow + 86400)), "q7_pct@claude-bar 3")
[IO.File]::WriteAllText($barPath, (($lines -join "`n") + "`n"), (New-Object Text.UTF8Encoding($false)))
$barAcc = [PSCustomObject]@{ Label = "barre"; Dir = ".claude-bar" }
try {
  Assert-Equal (Get-ClmText "ui.usage.notSignedIn") (Get-AccountUsage $barAcc).Error "barre d'etat recente : ignoree, seule l'API compte"
  Assert-True (-not (New-MenuEntry $barAcc @{} 0).Seen) "barre d'etat recente : carte vide a l'ouverture"
  Assert-Null (Get-LatestUsage $barAcc) "barre d'etat recente : aucune valeur reprise"
} finally {
  Remove-Item -LiteralPath $barPath -Force
  if ($null -ne $barKept) { [IO.File]::WriteAllBytes($barPath, $barKept) }
}
