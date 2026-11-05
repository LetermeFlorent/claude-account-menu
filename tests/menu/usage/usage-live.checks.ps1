$liveNow = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$liveAcc = [PSCustomObject]@{ Label = "live"; Dir = ".claude-live" }

function Set-LiveState {
  param([long]$At, [int]$Pct5)
  Save-UsageEntry "live" ([PSCustomObject]@{ Pct5 = $Pct5; Reset5 = [DateTimeOffset]::FromUnixTimeSeconds($liveNow + 3600).ToString("o"); Pct7 = 3; Reset7 = [DateTimeOffset]::FromUnixTimeSeconds($liveNow + 86400).ToString("o") }) $At
  [IO.File]::SetLastWriteTimeUtc($script:UsageCachePath, [DateTime]::UtcNow.AddSeconds($Pct5))
}

Set-LiveState ($liveNow - 5) 20
$st = New-MenuState @($liveAcc) 0 $false
$le = $st.Entries[0]
Assert-Equal 20 $le.U.Pct5 "cache recent, carte remplie a l'ouverture"
$le.Pending = $false
$le.NextAt = 9000000
Set-LiveState ($liveNow - 1) 55
Step-MenuLoader $st 1000
Assert-Equal 55 $le.U.Pct5 "cache plus recent, lu par un autre clm : carte mise a jour sans attendre l'API"
Assert-Equal ($liveNow - 1) $le.U.At "heure de la valeur reprise du cache"
Assert-True $st.Dirty "carte a redessiner apres le cache"
Assert-Null $st.Loader "aucun appel a l'API pour une valeur du cache"
Assert-True ($le.NextAt -lt 9000000) "prochaine lecture de l'API recalee sur la valeur du cache"

$le.U.LimitedUntil = $liveNow + 300
$le.NextAt = Get-NextReadAt $le 1000
$pauseAt = $le.NextAt
Set-LiveState $liveNow 70
Step-MenuLoader $st 1500
Assert-Equal 55 $le.U.Pct5 "fichier relu au plus toutes les 2 s"
Step-MenuLoader $st 3100
Assert-Equal 70 $le.U.Pct5 "pause de l'API : le cache met quand meme la carte a jour"
Assert-True ($le.U.LimitedUntil -gt $liveNow) "pause de l'API gardee"
Assert-Equal $pauseAt $le.NextAt "pause de l'API : relecture toujours a sa fin"
Assert-True ((Get-EntryTimer $le $false 3100)[0].StartsWith((Get-ClmText "menu.timer.apiPause" @("")))) "compteur de la pause garde"

Set-LiveState ($liveNow - 100) 10
Step-MenuLoader $st 5200
Assert-Equal 70 $le.U.Pct5 "valeur plus ancienne du cache ignoree"
$old = New-UsageRow $liveAcc "live@x.fr"
$old.Pct5 = 33; $old.At = $liveNow - 50; $old.LimitedUntil = $liveNow + 600
$le.Pending = $true
Set-UsageResult $st @(0, $old, $null) 6000
Assert-Equal 70 $le.U.Pct5 "resultat plus ancien que le cache : carte gardee"
Assert-Equal ($liveNow + 600) $le.U.LimitedUntil "resultat plus ancien : pause de l'API reprise"

Set-LiveState ($liveNow + 1) 72
Step-MenuLoader $st 8200
Assert-Equal 72 $le.U.Pct5 "cache plus recent : carte mise a jour"
Save-UsageEntry "live" ([PSCustomObject]@{ Pct5 = 81; Reset5 = $null; Pct7 = 2; Reset7 = $null })
Assert-Equal 81 (Get-LatestUsage $liveAcc).Pct5 "valeur la plus recente d'un compte, cache"
Save-UsageEntry "live" ([PSCustomObject]@{ Pct5 = 88; Reset5 = $null; Pct7 = 2; Reset7 = $null }) ($liveNow + 20)
Step-MenuLoader $st 12000
Assert-Equal 88 $le.U.Pct5 "autre clm : sa lecture reprise par ce menu"
Assert-True ($null -eq $st.Loader -and $le.NextAt -gt 12000) "autre clm : pas d'appel, prochaine lecture recalee sur la sienne"
$m = Read-UsageCache
$m.Remove("live")
Write-UsageCache $m
