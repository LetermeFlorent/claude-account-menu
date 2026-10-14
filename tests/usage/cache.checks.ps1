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
