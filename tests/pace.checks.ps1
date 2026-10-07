$now = New-Object DateTimeOffset ((Get-Date).Date.AddHours(12))

function Get-PaceText {
  param([string]$Kind, $Pct, [double]$LeftSeconds)
  $p = Get-UsagePace $Kind $Pct $now.AddSeconds($LeftSeconds) $now
  if ($p -eq $null) { return $null }
  return $p.Text + " | " + $p.Tone
}

Assert-Equal "faible | ok" (Get-PaceText "5h" 20 9000) "5h faible"
Assert-Equal "normal | dim" (Get-PaceText "5h" 35 9000) "5h projection 70, normal"
Assert-Equal "normal | dim" (Get-PaceText "5h" 50 9000) "5h projection 100, normal"
Assert-Equal "fort | warn" (Get-PaceText "5h" 60 9000) "5h fort"
Assert-Equal "fort | warn" (Get-PaceText "5h" 65 9000) "5h projection 130, fort"
Assert-Equal "excessif | alert" (Get-PaceText "5h" 80 9000) "5h excessif"
Assert-Equal "debut | dim" (Get-PaceText "5h" 30 17000) "5h debut"
Assert-Equal "faible | ok" (Get-PaceText "5h" 0 16200) "5h part de 10 %, plus debut"
Assert-Equal "epuise | alert" (Get-PaceText "5h" 100 9000) "5h quota atteint"
Assert-Equal "epuise | alert" (Get-PaceText "5h" 104 17000) "quota atteint passe avant debut"

Assert-Equal "excessif | alert" (Get-PaceText "7d" 80 302400) "7d excessif"
Assert-Equal "fort | warn" (Get-PaceText "7d" 60 302400) "7d fort"
Assert-Equal "faible | ok" (Get-PaceText "7d" 10 302400) "7d faible"
Assert-Equal "debut | dim" (Get-PaceText "7d" 40 600000) "7d debut"

Assert-Null (Get-UsagePace "5h" $null $now.AddSeconds(9000) $now) "pourcentage manquant"
Assert-Null (Get-UsagePace "5h" 40 $null $now) "reset manquant"
Assert-Null (Get-UsagePace "5h" 40 "" $now) "reset vide"
Assert-Null (Get-UsagePace "5h" 40 $now.AddSeconds(-5) $now) "reset passe"
Assert-Null (Get-UsagePace "5h" 40 $now $now) "reset a l'instant"
Assert-Equal "fort" (Get-UsagePace "5h" 60 $now.AddSeconds(9000).ToString("o") $now).Text "reset en texte ISO"
Assert-Equal "fort" (Get-UsagePace "5h" 60 $now.AddSeconds(9000).UtcDateTime $now).Text "reset en DateTime UTC"
Assert-Null (ConvertTo-DateOffset "pas une date") "date illisible"

$u = [PSCustomObject]@{ Label = "compte1"; Email = "a@b.c"; Plan = "Max 5x"; Error = $null; Age = $null; Pct5 = 80; Reset5 = [DateTimeOffset]::Now.AddSeconds(9000).ToString("o"); Pct7 = 10; Reset7 = [DateTimeOffset]::Now.AddSeconds(302400).ToString("o") }
$row = Format-Row $u
Assert-True ($row -match "5h 80% reset \d\d:\d\d \(dans 2h\d\d\), excessif \| 7d 10% reset .+, faible$") ("clm --usage avec verdicts : " + $row)
$u.Pct5 = $null
Assert-True ((Format-Row $u) -notmatch "5h [^|]*, ") "clm --usage sans verdict quand le pourcentage manque"

function Get-UsageLines {
  param($U)
  $esc = [string][char]27
  return @(& { Write-UsageLine $U } 6>&1 | ForEach-Object { ("" + $_) -replace ($esc + "\[[0-9;]*m"), "" })
}

$u = [PSCustomObject]@{ Pct5 = 20; Reset5 = [DateTimeOffset]::Now.AddSeconds(9000); Pct7 = 10; Reset7 = [DateTimeOffset]::Now.AddSeconds(302400) }
$lines = @(Get-UsageLines $u)
Assert-Equal 1 $lines.Count "verdicts sur la ligne des barres"
Assert-True ($lines[0] -match "faible.*\|.*faible") "deux verdicts en ligne"
$u.Pct5 = 80; $u.Pct7 = 80
$lines = @(Get-UsageLines $u)
Assert-Equal 1 $lines.Count "mots les plus longs, toujours une ligne"
Assert-True ($lines[0] -match "excessif.*\|.*excessif") "deux verdicts excessif"
Assert-True ($lines[0].TrimEnd().Length -le $script:ViewWidth) ("largeur tenue : " + $lines[0].TrimEnd().Length)
$u.Pct5 = $null
$lines = @(Get-UsageLines $u)
Assert-True ($lines -join "`n" -notmatch "5h [^|]*(faible|normal|fort|excessif|debut|epuise)") "pas de verdict 5h sans pourcentage"
