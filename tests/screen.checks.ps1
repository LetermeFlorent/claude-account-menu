function Get-SegsText {
  param($Segs)
  $t = ""
  foreach ($s in $Segs) { $t += $s[0] }
  return $t
}

function Get-InkCount {
  param($Segs, $Rgb)
  $n = 0
  foreach ($s in $Segs) { if (($s[1] -join " ") -eq ($Rgb -join " ")) { $n += $s[0].Length } }
  return $n
}

$segs = New-Row
Add-BarSegs $segs "5h" 50 @(120, 110, 200) 20
$t = Get-SegsText $segs
Assert-Equal (($script:BarFull * 9) + $script:BarHalf + ($script:BarEmpty * 10)) $t "barre a moitie pleine, derniere case reduite"
Assert-Equal 10 (Get-InkCount $segs $script:Ink.Cell) "cases vides a la couleur des cases"
Assert-Equal "120 110 200" ($segs[0][1] -join " ") "premiere case a la couleur du niveau"
Assert-Equal "143 134 209" ($segs[9][1] -join " ") "derniere case eclaircie sur fond sombre"
$savedInk = $script:Ink
$script:Ink = $script:Palettes["light"]
$segs = New-Row
Add-BarSegs $segs "5h" 50 @(120, 110, 200) 20
Assert-Equal "97 89 162" ($segs[9][1] -join " ") "derniere case foncee sur fond clair"
$script:Ink = $savedInk
$segs = New-Row
Add-BarSegs $segs "7d" 0 @(1, 1, 1) 20
Assert-Equal ($script:BarEmpty * 20) (Get-SegsText $segs) "barre vide"
Assert-Equal 20 (Get-InkCount $segs $script:Ink.Cell) "barre vide, toutes les cases vides"
$segs = New-Row
Add-BarSegs $segs "7d" 150 @(1, 1, 1) 20
Assert-Equal (($script:BarFull * 19) + $script:BarHalf) (Get-SegsText $segs) "barre bornee"
Assert-Equal 4 (Get-BarCount 51 8) "remplissage au demi-carre pres"
Assert-Equal 1 (Get-BarCount 0.5 8) "valeur non nulle, une case au moins"
Assert-Equal 0 (Get-BarCount 0 8) "valeur nulle, aucune case"
$segs = New-Row
Add-UsageSegs $segs "7d" (New-Tween 100 100 0 0) "3d07h" $null 8 0 $true
$pct = @($segs | Where-Object { $_[0] -match "100%" })[0]
$lastCell = @($segs | Where-Object { $_[0] -eq $script:BarHalf })[0]
Assert-Equal ($lastCell[1] -join " ") ($pct[1] -join " ") "chiffre a la couleur de la barre a 100 %"
$segs = New-Row
Add-UsageSegs $segs "7d" (New-Tween 40 40 0 0) "3d07h" $null 8 0 $true
$pct = @($segs | Where-Object { $_[0] -match "40%" })[0]
Assert-Equal ($script:Ink.Text -join " ") ($pct[1] -join " ") "chiffre a la couleur du texte sous 100 %"
Assert-Equal "45m" (Format-Left ([DateTimeOffset]::Now.AddMinutes(45).AddSeconds(30))) "moins d'une heure en minutes"
Assert-Equal "3h29m" (Format-Left ([DateTimeOffset]::Now.AddHours(3).AddMinutes(29).AddSeconds(30))) "heures et minutes"
Assert-Equal "3d07h" (Format-Left ([DateTimeOffset]::Now.AddDays(3).AddHours(7).AddMinutes(10))) "jours et heures"
Assert-Equal "0m" (Format-Left ([DateTimeOffset]::Now.AddSeconds(-5))) "remise a zero passee"
Assert-Equal "-" (Format-Left $null) "remise a zero inconnue"
$segs = New-Row
Add-ShimmerSegs $segs 20 600
Assert-Equal 20 (Get-SegsText $segs).Length "scintillement sur toute la barre"
$segs = New-Row
Add-ProgressSegs $segs -1 20 400
Assert-Equal 20 (Get-SegsText $segs).Length "progression sans pourcentage sur toute la barre"
$segs = New-Row
Add-ProgressSegs $segs 25 20 0
Assert-Equal 5 (Get-InkCount $segs $script:Levels["7d"][0]) "progression a un quart"
Assert-Equal (($script:BarFull * 4) + $script:BarHalf + ($script:BarEmpty * 15)) (Get-SegsText $segs) "progression terminee par une case reduite"
$tw = New-Tween 0 80 400 0
Assert-Equal "120 110 200" ((Get-BarBase "5h" $tw 0) -join " ") "couleur au depart de l'animation"
Assert-Equal "200 60 95" ((Get-BarBase "5h" $tw 400) -join " ") "couleur a l'arrivee"

function New-TestCard {
  param([string]$Label, $P5, $P7, $Err = $null, [bool]$Pending = $false)
  $u = [PSCustomObject]@{ Label = $Label; Email = ($Label + "@exemple.fr"); Plan = "Max 5x"; Error = $Err; Age = $null; Expired = $false
    Pct5 = $P5; Reset5 = [DateTimeOffset]::Now.AddHours(2); Pct7 = $P7; Reset7 = [DateTimeOffset]::Now.AddDays(3) }
  $e = @{ U = $u; Pending = $Pending; Seen = (-not $Pending); In = $null; View = $null; T5 = (New-Tween ([double]$P5) ([double]$P5) 0 0); T7 = (New-Tween ([double]$P7) ([double]$P7) 0 0) }
  Update-EntryView $e
  return $e
}

$cards = @((New-TestCard "perso" 20 100), (New-TestCard "pro" $null $null "jeton refuse, lancer le compte une fois"), (New-TestCard "test" $null $null $null $true))
$st = @{ Entries = $cards; Sel = 0; SelTween = (New-Tween 0 0 0 0); Top = 0; Msg = @("  pret", $script:Ink.Dim); Moved = $false }
$L = Get-MenuLayout 120 40 3
$f = Get-MenuRows $st $L 0
$texts = @(foreach ($r in $f.Rows) { Get-SegsText $r })
Assert-Equal 22 $f.Rows.Count "trois cartes completes en 120x40"
Assert-Equal 22 $f.Fades.Count "un fondu par rangee"
Assert-True (@($texts | Where-Object { $_.Length -gt $L.Clip }).Count -eq 0) "aucune rangee au-dela du bord"
Assert-True ($texts[4].StartsWith("  " + $script:Mark + " 1  perso")) "repere sur le compte choisi"
Assert-True ($texts[4].EndsWith("quota 7d atteint  Max 5x")) "badge et offre a droite"
Assert-Equal ($L.W - 2) $texts[4].Length "texte de droite cale sur la largeur"
Assert-True ($texts[6] -match "^  . {4}5h ") "barre 5h sous le repere"
Assert-True ($texts[11] -match "jeton refuse") "erreur a la place des barres"
Assert-True ($texts[16] -match "lecture\.\.\.") "compte encore en lecture"
Assert-Equal 1 $f.Fades[4] "carte choisie a pleine intensite"
Assert-Equal 0.65 $f.Fades[9] "autre carte attenuee"
Assert-Equal "  pret" $texts[21] "message en pied"

$L = Get-MenuLayout 80 12 3
$st.Sel = 2
$st.SelTween = New-Tween 2 2 0 0
$f = Get-MenuRows $st $L 0
$texts = @(foreach ($r in $f.Rows) { Get-SegsText $r })
Assert-Equal 2 $st.Top "defilement jusqu'au compte choisi"
Assert-True ($texts[2].EndsWith($script:UpArrow)) "fleche haut quand des comptes sont caches"
Assert-True ($texts[4] -match "3  test  test@exemple.fr") "vue compacte, nom et e-mail sur une ligne"

$L = Get-MenuLayout 30 10 3
$f = Get-MenuRows $st $L 0
$texts = @(foreach ($r in $f.Rows) { Get-SegsText $r })
Assert-Equal 5 $f.Rows.Count "vue simple, titre, comptes et message"
Assert-True ($texts[1] -match "1  perso  5h 20%  7d 100%") "vue simple, quotas en texte"
Assert-True ($texts[3].StartsWith(" " + $script:Mark + " 3  test  lecture")) "vue simple, compte choisi en lecture"

$st.Moved = $false
$st.Sel = 0
$st.Entries = @((New-TestCard "a" 100 1), (New-TestCard "b" $null $null $null $true), (New-TestCard "c" 1 1 $null $true))
$res = [PSCustomObject]@{ Label = "b"; Email = "b@x.fr"; Plan = ""; Error = $null; Age = $null; Expired = $false; Pct5 = 10; Reset5 = $null; Pct7 = 5; Reset7 = $null }
Set-UsageResult $st @(1, $res, $null) 1000
Assert-Equal 1 $st.Sel "la selection glisse vers le premier compte libre"
Assert-Equal 10 $st.Entries[1].T5.To "barre animee vers la valeur lue"
Assert-True (Test-TweenRunning $st.Entries[1].T5 1200) "remplissage anime"
Set-UsageResult $st @(2, $null, "panne") 1000
Assert-Equal "panne" $st.Entries[2].U.Error "erreur du chargeur affichee"
$st.Sel = 0
$st.Moved = $true
Set-UsageResult $st @(1, $res, $null) 2000
Assert-Equal 0 $st.Sel "choix de l'utilisateur garde"
Assert-True (-not (Test-TweenRunning $st.Entries[1].T5 2000)) "valeur inchangee, barre immobile"
$res.Pct5 = 20
Set-UsageResult $st @(1, $res, $null) 3000
Assert-True (Test-TweenRunning $st.Entries[1].T5 3100) "valeur changee, barre animee"
Assert-True (-not (Test-TweenRunning $st.Entries[1].T7 3100)) "autre barre inchangee, immobile"

$st = @{ Entries = @((New-TestCard "a" 10 10), (New-TestCard "b" 20 20)); Busy = $false; Loader = $null; DoneAt = 1000 }
Assert-Equal "maj dans 30s" (Get-UpdateSeg $st 1000)[0] "compteur au depart"
Assert-Equal "maj dans 8s" (Get-UpdateSeg $st 23500)[0] "compteur arrondi a la seconde du dessus"
Assert-Equal "maj dans 0s" (Get-UpdateSeg $st 40000)[0] "compteur jamais negatif"
Assert-True (Update-MenuHead $st 1000) "en-tete redessine au premier passage"
Assert-True (-not (Update-MenuHead $st 1200)) "meme seconde, rien a redessiner"
Assert-True (Update-MenuHead $st 2100) "seconde suivante, en-tete redessine"
$st.Entries[1].U.Age = 300
Assert-Equal "maj en echec (b), reessai dans 30s" (Get-UpdateSeg $st 1000)[0] "echec signale avec le compte"
Assert-Equal ($script:Ink.Alert -join " ") ((Get-UpdateSeg $st 1000)[1] -join " ") "echec en rouge"
$st.Entries[0].U.Error = "panne"
Assert-Equal "maj en echec (2 comptes), reessai dans 30s" (Get-UpdateSeg $st 1000)[0] "plusieurs echecs comptes"
$st.Loader = @{}
Assert-Equal "maj en cours" (Get-UpdateSeg $st 1000)[0] "lecture en cours"
$st.Busy = $true
Assert-Equal "maj en pause" (Get-UpdateSeg $st 1000)[0] "relecture suspendue pendant une action"
