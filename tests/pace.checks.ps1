$now = New-Object DateTimeOffset ((Get-Date).Date.AddHours(12))
$inv = [Globalization.CultureInfo]::InvariantCulture

function Get-PaceText {
  param([string]$Kind, $Pct, [double]$LeftSeconds)
  $p = Get-UsagePace $Kind $Pct $now.AddSeconds($LeftSeconds) $now
  if ($p -eq $null) { return $null }
  return $p.Text + " | " + $p.Tone
}

Assert-Equal "large | ok" (Get-PaceText "5h" 20 9000) "5h large"
Assert-Equal "bon rythme | dim" (Get-PaceText "5h" 35 9000) "5h projection 70, bon rythme"
Assert-Equal "bon rythme | dim" (Get-PaceText "5h" 50 9000) "5h projection 100, bon rythme"
Assert-Equal "agressif, max 16%/h | warn" (Get-PaceText "5h" 60 9000) "5h agressif"
Assert-Equal "agressif, max 14%/h | warn" (Get-PaceText "5h" 65 9000) "5h projection 130, agressif"
Assert-Equal "trop, coupe vers 12:37, max 8%/h | alert" (Get-PaceText "5h" 80 9000) "5h trop, heure de coupure"
Assert-Equal "trop tot | dim" (Get-PaceText "5h" 30 17000) "5h trop tot"
Assert-Equal "large | ok" (Get-PaceText "5h" 0 16200) "5h part de 10 %, plus trop tot"
Assert-Equal "coupe jusqu'au reset | alert" (Get-PaceText "5h" 100 9000) "5h quota atteint"
Assert-Equal "coupe jusqu'au reset | alert" (Get-PaceText "5h" 104 17000) "quota atteint passe avant trop tot"

$tomorrow = $now.AddSeconds(75600).ToString("dd/MM HH:mm", $inv)
Assert-Equal ("trop, coupe vers " + $tomorrow + ", max 6%/j | alert") (Get-PaceText "7d" 80 302400) "7d trop, coupure un autre jour"
Assert-Equal "agressif, max 11%/j | warn" (Get-PaceText "7d" 60 302400) "7d agressif"
Assert-Equal "large | ok" (Get-PaceText "7d" 10 302400) "7d large"
Assert-Equal "trop tot | dim" (Get-PaceText "7d" 40 600000) "7d trop tot"

Assert-Null (Get-UsagePace "5h" $null $now.AddSeconds(9000) $now) "pourcentage manquant"
Assert-Null (Get-UsagePace "5h" 40 $null $now) "reset manquant"
Assert-Null (Get-UsagePace "5h" 40 "" $now) "reset vide"
Assert-Null (Get-UsagePace "5h" 40 $now.AddSeconds(-5) $now) "reset passe"
Assert-Null (Get-UsagePace "5h" 40 $now $now) "reset a l'instant"
Assert-Equal "agressif, max 16%/h" (Get-UsagePace "5h" 60 $now.AddSeconds(9000).ToString("o") $now).Text "reset en texte ISO"
Assert-Equal "agressif, max 16%/h" (Get-UsagePace "5h" 60 $now.AddSeconds(9000).UtcDateTime $now).Text "reset en DateTime UTC"

Assert-Equal "12:37" (Format-CutTime $now.AddSeconds(2250) $now) "coupure le jour meme"
Assert-Equal ($now.AddDays(1).ToString("dd/MM", $inv) + " 12:00") (Format-CutTime $now.AddDays(1) $now) "coupure le lendemain"
Assert-Null (ConvertTo-DateOffset "pas une date") "date illisible"

$u = [PSCustomObject]@{ Label = "compte1"; Email = "a@b.c"; Plan = "Max 5x"; Error = $null; Age = $null; Pct5 = 80; Reset5 = [DateTimeOffset]::Now.AddSeconds(9000).ToString("o"); Pct7 = 10; Reset7 = [DateTimeOffset]::Now.AddSeconds(302400).ToString("o") }
$row = Format-Row $u
Assert-True ($row -match "5h 80% reset \d\d:\d\d \(dans 2h\d\d\), trop, coupe vers \d\d:\d\d, max 8%/h \| 7d 10% reset .+, large$") ("clm --usage avec verdicts : " + $row)
$u.Pct5 = $null
Assert-True ((Format-Row $u) -notmatch "5h [^|]*, ") "clm --usage sans verdict quand le pourcentage manque"

function Get-UsageLines {
  param($U)
  $esc = [string][char]27
  return @(& { Write-UsageLine $U } 6>&1 | ForEach-Object { ("" + $_) -replace ($esc + "\[[0-9;]*m"), "" })
}

$u = [PSCustomObject]@{ Pct5 = 20; Reset5 = [DateTimeOffset]::Now.AddSeconds(9000); Pct7 = 10; Reset7 = [DateTimeOffset]::Now.AddSeconds(302400) }
$lines = @(Get-UsageLines $u)
Assert-Equal 1 $lines.Count "verdicts courts sur la ligne des barres"
Assert-True ($lines[0] -match "large.*\|.*large") "deux verdicts en ligne"
$u.Pct5 = 80
$lines = @(Get-UsageLines $u)
Assert-Equal 2 $lines.Count "verdict long, seconde ligne"
Assert-True ($lines[1] -match "^\s+5h trop, coupe vers .+   7d large\s*$") ("seconde ligne : " + $lines[1])
$u.Pct7 = 80
$lines = @(Get-UsageLines $u)
Assert-Equal 3 $lines.Count "deux verdicts longs, une ligne chacun"
foreach ($l in $lines) { Assert-True ($l.TrimEnd().Length -le $script:ViewWidth) ("largeur tenue : " + $l.TrimEnd().Length) }
$u.Pct5 = $null
$lines = @(Get-UsageLines $u)
Assert-True ($lines -join "`n" -notmatch "5h (large|trop|bon|agressif)") "pas de verdict 5h sans pourcentage"
