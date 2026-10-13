function Get-SegsText {
  param($Segs)
  $t = ""
  foreach ($s in $Segs) { $t += $s[0] }
  return $t
}

function Get-GlyphCount {
  param([string]$Text, [string]$Glyph)
  return ($Text.Length - $Text.Replace($Glyph, "").Length)
}

$segs = New-Row
Add-BarSegs $segs "5h" 50 @(120, 110, 200) 20
$t = Get-SegsText $segs
Assert-Equal "10 10" ("" + (Get-GlyphCount $t $script:BarFull) + " " + (Get-GlyphCount $t $script:BarEmpty)) "barre a moitie pleine"
Assert-Equal "120 110 200" ($segs[0][1] -join " ") "premiere bande a la couleur du niveau"
$segs = New-Row
Add-BarSegs $segs "7d" 0 @(1, 1, 1) 20
Assert-Equal ($script:BarEmpty * 20) (Get-SegsText $segs) "barre vide"
$segs = New-Row
Add-BarSegs $segs "7d" 150 @(1, 1, 1) 20
Assert-Equal ($script:BarFull * 20) (Get-SegsText $segs) "barre bornee"
$segs = New-Row
Add-ShimmerSegs $segs 20 600
Assert-Equal 20 (Get-SegsText $segs).Length "scintillement sur toute la barre"
$segs = New-Row
Add-ProgressSegs $segs -1 20 400
Assert-Equal 20 (Get-SegsText $segs).Length "progression sans pourcentage sur toute la barre"
$segs = New-Row
Add-ProgressSegs $segs 25 20 0
Assert-Equal 5 (Get-GlyphCount (Get-SegsText $segs) $script:BarFull) "progression a un quart"
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
