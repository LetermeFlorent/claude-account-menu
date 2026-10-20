$barPath = Get-StatusStatePath
New-Item -ItemType Directory -Force -Path (Split-Path $barPath) | Out-Null
$barNow = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$barR5 = $barNow + 3600
$barR7 = $barNow + 86400

function Set-BarState {
  param([long]$At)
  $lines = @("theme dark", ("q_at@claude-bar " + $At), ("q5_at@claude-bar " + $barR5 + ".7"), "q5_pct@claude-bar 10.6", ("q7_at@claude-bar " + $barR7), "q7_pct@claude-bar 3", ("q_at@claude-moitie " + $barNow), ("q5_at@claude-moitie " + $barR5))
  [IO.File]::WriteAllText($barPath, (($lines -join "`r`n") + "`r`n"), (New-Object Text.UTF8Encoding($false)))
}

function Set-CacheAt {
  param([string]$Label, [long]$At)
  $m = Read-UsageCache
  $m[$Label].At = $At
  Write-UsageCache $m
}

$barAcc = [PSCustomObject]@{ Label = "barre"; Dir = ".claude-bar" }
Set-BarState ($barNow - 20)
$b = Read-StatusUsage $barAcc
Assert-Equal ($barNow - 20) $b.At "barre : heure de sa derniere lecture"
Assert-Equal 11 $b.Pct5 "barre : pourcentage 5h arrondi, point decimal lu quelle que soit la langue"
Assert-Equal $barR5 (ConvertTo-DateOffset $b.Reset5).ToUnixTimeSeconds() "barre : reset 5h relu"
Assert-Equal 3 $b.Pct7 "barre : pourcentage 7j"
Assert-Equal $barR7 (ConvertTo-DateOffset $b.Reset7).ToUnixTimeSeconds() "barre : reset 7j relu"
Assert-Null (Read-StatusUsage ([PSCustomObject]@{ Label = "moitie"; Dir = ".claude-moitie" })) "barre sans pourcentage : ignoree"
Assert-Null (Read-StatusUsage ([PSCustomObject]@{ Label = "autre"; Dir = ".claude-autre" })) "barre sans ce compte : ignoree"

$u = Get-AccountUsage $barAcc
Assert-Null $u.Error "barre lue il y a 20 s : chiffres repris sans appel a l'API"
Assert-Equal 11 $u.Pct5 "barre lue il y a 20 s : pourcentage de la barre"
Assert-True ($u.Age -ge 20 -and $u.Age -le 25) "barre lue il y a 20 s : age affiche"
Assert-True (New-MenuEntry $barAcc @{} 0).Seen "barre recente : carte remplie des l'ouverture"
Set-BarState ($barNow - 60)
Assert-Equal "non connecte" (Get-FreshUsage $barAcc).Error "relecture forcee, barre de plus de 30 s : appel a l'API"
Assert-Equal 11 (Get-AccountUsage $barAcc).Pct5 "lecture normale, barre de moins de 3 min : reprise"
Set-BarState ($barNow - 400)
Assert-Equal "non connecte" (Get-AccountUsage $barAcc).Error "barre de plus de 3 min : appel a l'API"

Save-UsageEntry "barre" ([PSCustomObject]@{ Pct5 = 50; Reset5 = $null; Pct7 = 6; Reset7 = $null })
Set-BarState ($barNow - 20)
Assert-Equal 50 (Get-AccountUsage $barAcc).Pct5 "cache de clm plus recent que la barre : cache"
Set-CacheAt "barre" ($barNow - 100)
Assert-Equal 11 (Get-AccountUsage $barAcc).Pct5 "barre plus recente que le cache de clm : barre"
Save-UsageCooldown "barre" 120 2
Set-CacheAt "barre" ($barNow - 1000)
Set-BarState ($barNow - 400)
$u = Get-AccountUsage $barAcc
Assert-Equal 11 $u.Pct5 "pause de l'API : chiffres les plus recents, ceux de la barre"
Assert-True ($u.LimitedUntil -gt $barNow) "pause de l'API : gardee"

$m = Read-UsageCache
$m.Remove("barre")
Write-UsageCache $m
Remove-Item -LiteralPath $barPath -Force
