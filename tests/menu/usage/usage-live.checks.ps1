$livePath = Get-StatusStatePath
New-Item -ItemType Directory -Force -Path (Split-Path $livePath) | Out-Null
$liveNow = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$liveAcc = [PSCustomObject]@{ Label = "live"; Dir = ".claude-live" }

function Set-LiveState {
  param([long]$At, [int]$Pct5)
  $lines = @("theme dark", ("q_at@claude-live " + $At), ("q5_at@claude-live " + ($liveNow + 3600)), ("q5_pct@claude-live " + $Pct5), ("q7_at@claude-live " + ($liveNow + 86400)), "q7_pct@claude-live 3")
  [IO.File]::WriteAllText($livePath, (($lines -join "`n") + "`n"), (New-Object Text.UTF8Encoding($false)))
  [IO.File]::SetLastWriteTimeUtc($livePath, [DateTime]::UtcNow.AddSeconds($Pct5))
}

Set-LiveState ($liveNow - 5) 20
$st = New-MenuState @($liveAcc) 0 $false
$le = $st.Entries[0]
Assert-Equal 20 $le.U.Pct5 "barre recente, carte remplie a l'ouverture"
$le.Pending = $false
$le.NextAt = 9000000
Set-LiveState ($liveNow - 1) 55
Step-MenuLoader $st 1000
Assert-Equal 55 $le.U.Pct5 "fichier de la barre plus recent : carte mise a jour sans attendre l'API"
Assert-Equal ($liveNow - 1) $le.U.At "heure de la valeur reprise de la barre"
Assert-True $st.Dirty "carte a redessiner apres la barre"
Assert-Null $st.Loader "aucun appel a l'API pour une valeur de la barre"
Assert-True ($le.NextAt -lt 9000000) "prochaine lecture de l'API recalee sur la valeur de la barre"

$le.U.LimitedUntil = $liveNow + 300
$le.NextAt = Get-NextReadAt $le 1000
$pauseAt = $le.NextAt
Set-LiveState $liveNow 70
Step-MenuLoader $st 1500
Assert-Equal 55 $le.U.Pct5 "fichier relu au plus toutes les 2 s"
Step-MenuLoader $st 3100
Assert-Equal 70 $le.U.Pct5 "pause de l'API : la barre met quand meme la carte a jour"
Assert-True ($le.U.LimitedUntil -gt $liveNow) "pause de l'API gardee"
Assert-Equal $pauseAt $le.NextAt "pause de l'API : relecture toujours a sa fin"
Assert-True ((Get-EntryTimer $le $false 3100)[0].StartsWith((Get-ClmText "menu.timer.apiPause" @("")))) "compteur de la pause garde"

Set-LiveState ($liveNow - 100) 10
Step-MenuLoader $st 5200
Assert-Equal 70 $le.U.Pct5 "valeur plus ancienne de la barre ignoree"
$old = New-UsageRow $liveAcc "live@x.fr"
$old.Pct5 = 33; $old.At = $liveNow - 50; $old.LimitedUntil = $liveNow + 600
$le.Pending = $true
Set-UsageResult $st @(0, $old, $null) 6000
Assert-Equal 70 $le.U.Pct5 "resultat plus ancien que la barre : carte gardee"
Assert-Equal ($liveNow + 600) $le.U.LimitedUntil "resultat plus ancien : pause de l'API reprise"

$sidePath = $livePath + ".4242.changes"
[IO.File]::WriteAllText($sidePath, ("q_at@claude-live " + ($liveNow + 9) + "`nq5_pct@claude-live 99`n"), (New-Object Text.UTF8Encoding($false)))
Set-LiveState ($liveNow + 1) 72
Step-MenuLoader $st 8200
Assert-Equal 72 $le.U.Pct5 "fichier state.<pid>.changes a cote : seul le fichier state est lu"
Set-LiveState ($liveNow - 2) 64
Assert-Equal 64 (Get-LatestUsage $liveAcc).Pct5 "fichier state.<pid>.changes ignore par la valeur la plus recente"
Remove-Item -LiteralPath $sidePath -Force
Assert-Equal 64 (Get-LatestUsage $liveAcc).Pct5 "valeur la plus recente d'un compte, barre"
Save-UsageEntry "live" ([PSCustomObject]@{ Pct5 = 81; Reset5 = $null; Pct7 = 2; Reset7 = $null })
Assert-Equal 81 (Get-LatestUsage $liveAcc).Pct5 "valeur la plus recente d'un compte, cache"
$m = Read-UsageCache
$m.Remove("live")
Write-UsageCache $m
Remove-Item -LiteralPath $livePath -Force
