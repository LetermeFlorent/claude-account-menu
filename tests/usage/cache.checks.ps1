$past = [DateTimeOffset]::UtcNow.AddHours(-2).ToString("o")
$future = [DateTimeOffset]::UtcNow.AddHours(3).ToString("o")
$entry = [PSCustomObject]@{ At = [DateTimeOffset]::UtcNow.AddHours(-16).ToUnixTimeSeconds(); Pct5 = 40; Reset5 = $future; Pct7 = 100; Reset7 = $past }
$out = [PSCustomObject]@{ Pct5 = $null; Reset5 = $null; Pct7 = $null; Reset7 = $null; Age = $null; Expired = $false }
Copy-CacheEntry $entry $out
Assert-Equal 40 $out.Pct5 "cache 5h encore valide garde sa valeur"
Assert-Equal $future $out.Reset5 "cache 5h encore valide garde son reset"
Assert-Equal 0 $out.Pct7 "cache 7d au reset passe remis a 0"
Assert-Null $out.Reset7 "cache 7d au reset passe sans reset"
Assert-True $out.Expired "cache au reset passe marque perime"

Assert-Equal 60 (Get-CooldownSeconds 1 0 0) "premier refus, une minute de pause"
Assert-Equal 240 (Get-CooldownSeconds 3 0 0) "pause doublee a chaque refus"
Assert-Equal 600 (Get-CooldownSeconds 9 0 0) "pause plafonnee a dix minutes"
Assert-Equal 127 (Get-CooldownSeconds 2 0 7) "part de hasard ajoutee"
Assert-Equal 1800 (Get-CooldownSeconds 1 1800 3) "Retry-After plus long respecte"
Assert-Equal 3600 (Get-CooldownSeconds 1 99999 0) "Retry-After plafonne a une heure"

Save-UsageEntry "pause" ([PSCustomObject]@{ Pct5 = 5; Reset5 = $null; Pct7 = 6; Reset7 = $null })
Save-UsageCooldown "pause" 120 2
$c = (Read-UsageCache)["pause"]
Assert-Equal 2 $c.Fails "refus comptes dans le cache"
Assert-True ((Get-CooldownLeft $c) -ge 119) "fin de pause gardee dans le cache"
Assert-Equal 5 $c.Pct5 "chiffres gardes pendant la pause"
$u = Get-AccountUsage ([PSCustomObject]@{ Label = "pause"; Dir = ".claude-pause" }) 0
Assert-Equal 5 $u.Pct5 "pause en cours, chiffres du cache sans appel"
Assert-Null $u.Error "pause en cours, pas d'erreur"
Assert-True ($u.LimitedUntil -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) "pause signalee au menu"
Save-UsageEntry "pause" ([PSCustomObject]@{ Pct5 = 7; Reset5 = $null; Pct7 = 6; Reset7 = $null })
$c = (Read-UsageCache)["pause"]
Assert-Equal 0 (Get-CooldownLeft $c) "lecture reussie, pause levee"
Assert-Equal 0 ([int]$c.Fails) "lecture reussie, refus remis a zero"
Save-UsageCooldown "vide" 90 1
$u = Get-AccountUsage ([PSCustomObject]@{ Label = "vide"; Dir = ".claude-vide" }) 0
Assert-Equal "quota inconnu, l'API de suivi refuse les appels (reessai dans 1min)" $u.Error "pause sans chiffres connus"
