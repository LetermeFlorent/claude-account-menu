$l = Get-MenuLayout 120 40 3
Assert-Equal "full 105 48 3 119" ($l.Mode + " " + $l.W + " " + $l.Cells + " " + $l.Visible + " " + $l.Clip) "grand terminal, cartes completes"
$l = Get-MenuLayout 80 20 3
Assert-Equal "compact 77 8 3 2" ($l.Mode + " " + $l.W + " " + $l.Cells + " " + $l.Visible + " " + $l.FooterRows) "terminal moyen, vue compacte"
$l = Get-MenuLayout 80 12 3
Assert-Equal "compact 1" ($l.Mode + " " + $l.Visible) "terminal bas, un compte visible"
Assert-Equal "simple" (Get-MenuLayout 39 30 3).Mode "terminal etroit, vue simple"
Assert-Equal "simple True" ((Get-MenuLayout 40 30 3).Mode + " " + ((Get-MenuLayout 41 30 3).Mode -ne "simple")) "cadre trop large sous 41 colonnes, vue simple"
$l = Get-MenuLayout 9 8 3
Assert-Equal "simple 3 8" ($l.Mode + " " + $l.Visible + " " + $l.Clip) "terminal minuscule, vue simple"
Assert-Equal 3 (Get-MenuLayout 60 40 2).FooterRows "pied sur trois lignes a 60 colonnes"
Assert-Equal 2 (Get-MenuLayout 200 40 2).FooterRows "pied sur deux lignes a la largeur maximale"
function Get-FooterLengths {
  param([int]$W)
  return (@(foreach ($r in (Get-FooterRows (Get-MenuFooter) $W)) { $t = ""; foreach ($s in $r) { $t += $s[0] }; $t.Length }) -join " ")
}
$footerSplit = @{ fr = "64 63"; en = "52 59" }[(Get-ClmLang)]
Assert-Equal $footerSplit (Get-FooterLengths 105) "pied equilibre entre ses deux lignes"
Assert-Equal $footerSplit (Get-FooterLengths 105) "pied relu depuis le cache, meme decoupe"
Assert-Equal (@{ fr = "127"; en = "111" }[(Get-ClmLang)]) (Get-FooterLengths 200) "pied sur une ligne quand tout tient"
Assert-Equal "full 3" ((Get-MenuLayout 120 40 3 4).Mode + " " + (Get-MenuLayout 120 40 3 4).Visible) "barres du lancement, cartes completes gardees"
$l = Get-MenuLayout 80 20 3 4
Assert-Equal "compact 2" ($l.Mode + " " + $l.Visible) "barres du lancement, un compte de moins en vue compacte"
Assert-Equal "simple 3" ((Get-MenuLayout 80 12 3 4).Mode + " " + (Get-MenuLayout 80 12 3 4).Visible) "barres du lancement, terminal bas en vue simple"
Assert-Equal "simple 2" ((Get-MenuLayout 30 8 3 4).Mode + " " + (Get-MenuLayout 30 8 3 4).Visible) "barres du lancement, vue simple raccourcie"
Assert-Equal 1 (Get-MenuLayout 30 5 3 4).Visible "barres du lancement, un compte visible au moins"

Assert-Equal 0 (Get-ScrollTop 0 2 3 6) "defilement vers le haut"
Assert-Equal 3 (Get-ScrollTop 5 0 3 6) "defilement vers le bas"
Assert-Equal 1 (Get-ScrollTop 2 1 3 6) "selection visible, rien ne bouge"
Assert-Equal 0 (Get-ScrollTop 1 4 9 3) "defilement borne"

function New-TestEntry { param($Pending, $P5, $P7, $Err) @{ Pending = $Pending; U = [pscustomobject]@{ Pct5 = $P5; Pct7 = $P7; Error = $Err } } }
$es = @((New-TestEntry $false 100 10 $null), (New-TestEntry $true $null $null $null), (New-TestEntry $false 5 5 $null))
Assert-Equal -1 (Get-ReadyDefault $es) "attente d'un compte encore en lecture"
Assert-Equal 1 (Get-ReadyDefault $es $false) "sans attente, premier compte non bloque"
$es[1] = New-TestEntry $false 1 1 "panne"
Assert-Equal 2 (Get-ReadyDefault $es) "compte en erreur saute"
$es[2] = New-TestEntry $false 5 100 $null
Assert-Equal 0 (Get-ReadyDefault $es) "aucun compte libre, le premier"

function New-TestKey { param([char]$C, [ConsoleKey]$K, [bool]$Ctrl = $false) New-Object System.ConsoleKeyInfo $C, $K, $false, $false, $Ctrl }
Assert-Equal "up" (Get-MenuAction (New-TestKey ([char]0) UpArrow) 3).Name "fleche haut"
Assert-Equal "down" (Get-MenuAction (New-TestKey ([char]0) DownArrow) 3).Name "fleche bas"
Assert-Equal "launch" (Get-MenuAction (New-TestKey ([char]13) Enter) 3).Name "Entree lance"
Assert-Equal "quit" (Get-MenuAction (New-TestKey ([char]27) Escape) 3).Name "Echap quitte"
Assert-Equal "quit" (Get-MenuAction (New-TestKey ([char]3) C $true) 3).Name "Ctrl+C quitte"
Assert-Equal "quit" (Get-MenuAction (New-TestKey ([char]'Q') Q) 3).Name "q majuscule quitte"
Assert-Equal "save" (Get-MenuAction (New-TestKey ([char]'s') S) 3).Name "s sauvegarde"
Assert-Equal "restore" (Get-MenuAction (New-TestKey ([char]'r') R) 3).Name "r restaure"
Assert-Equal "add" (Get-MenuAction (New-TestKey ([char]'a') A) 3).Name "a ajoute"
Assert-Equal "remove" (Get-MenuAction (New-TestKey ([char]'x') X) 3).Name "x retire"
$k = Get-MenuAction (New-TestKey ([char]'2') D2) 3
Assert-Equal "pick 1" ($k.Name + " " + $k.Index) "chiffre choisit le compte"
Assert-Equal "none" (Get-MenuAction (New-TestKey ([char]'4') D4) 3).Name "chiffre hors liste ignore"
Assert-Equal "none" (Get-MenuAction (New-TestKey ([char]'z') Z) 3).Name "touche inconnue ignoree"
