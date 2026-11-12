$l = Get-MenuLayout 120 40 3
Assert-Equal "full 105 48 3 119" ($l.Mode + " " + $l.W + " " + $l.Cells + " " + $l.Visible + " " + $l.Clip) "grand terminal, cartes completes"
$l = Get-MenuLayout 80 20 3
Assert-Equal "compact 77 8 3 1" ($l.Mode + " " + $l.W + " " + $l.Cells + " " + $l.Visible + " " + $l.FooterRows) "terminal moyen, vue compacte"
$l = Get-MenuLayout 80 12 3
Assert-Equal "compact 1" ($l.Mode + " " + $l.Visible) "terminal bas, un compte visible"
Assert-Equal "simple" (Get-MenuLayout 39 30 3).Mode "terminal etroit, vue simple"
Assert-Equal "simple True" ((Get-MenuLayout 40 30 3).Mode + " " + ((Get-MenuLayout 41 30 3).Mode -ne "simple")) "cadre trop large sous 41 colonnes, vue simple"
$l = Get-MenuLayout 9 8 3
Assert-Equal "simple 3 8" ($l.Mode + " " + $l.Visible + " " + $l.Clip) "terminal minuscule, vue simple"
Assert-Equal 2 (Get-MenuLayout 41 40 2).FooterRows "pied sur deux lignes a la largeur minimale"
Assert-Equal 1 (Get-MenuLayout 60 40 2).FooterRows "pied sur une ligne a 60 colonnes"
Assert-Equal 1 (Get-MenuLayout 200 40 2).FooterRows "pied sur une ligne a la largeur maximale"
function Get-FooterLengths {
  param([int]$W)
  return (@(foreach ($r in (Get-FooterRows (Get-MenuFooter) $W)) { $t = ""; foreach ($s in $r) { $t += $s[0] }; $t.Length }) -join " ")
}
$footerSplit = @{ fr = "30 23"; en = "25 28" }[(Get-ClmLang)]
Assert-Equal $footerSplit (Get-FooterLengths 38) "pied equilibre entre ses deux lignes"
Assert-Equal $footerSplit (Get-FooterLengths 38) "pied relu depuis le cache, meme decoupe"
Assert-Equal (@{ fr = "53"; en = "53" }[(Get-ClmLang)]) (Get-FooterLengths 200) "pied sur une ligne quand tout tient"
$footRoom = @(foreach ($w in 38, 50, 70, 77, 90, 105) { (Get-FooterRows (Get-MenuFooter) $w @() 21).Count - (Get-FooterRows (Get-MenuFooter) $w).Count })
Assert-Equal "0 0 0 0 0 0" ($footRoom -join " ") "pied : la place de la version de Claude Code n'ajoute jamais de ligne"
$footLast = (Get-FooterRows (Get-MenuFooter) 90 @() 21)[-1]
Assert-True ((Get-SegsLength $footLast) + 21 -le 88) "pied a 90 colonnes : version de Claude Code sur la derniere ligne"
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
Assert-Equal "none" (Get-MenuAction (New-TestKey ([char]'s') S) 3).Name "s ne fait rien"
Assert-Equal "none" (Get-MenuAction (New-TestKey ([char]'r') R) 3).Name "r ne fait rien"
Assert-Equal "none" (Get-MenuAction (New-TestKey ([char]'a') A) 3).Name "a ne fait rien"
Assert-Equal "none" (Get-MenuAction (New-TestKey ([char]'x') X) 3).Name "x ne fait rien"
Assert-Equal "none" (Get-MenuAction (New-TestKey ([char]'n') N) 3).Name "n ne fait rien"
Assert-Equal "none" (Get-MenuAction (New-TestKey ([char]'p') P) 3).Name "p ne fait rien"
$k = Get-MenuAction (New-TestKey ([char]'2') D2) 3
Assert-Equal "pick 1" ($k.Name + " " + $k.Index) "chiffre choisit le compte"
Assert-Equal "none" (Get-MenuAction (New-TestKey ([char]'4') D4) 3).Name "chiffre hors liste ignore"
Assert-Equal "none" (Get-MenuAction (New-TestKey ([char]'z') Z) 3).Name "touche inconnue ignoree"
$footSplit = (Get-Item "function:Split-FooterPairs").ScriptBlock
$footInk = $script:Ink
try {
  $script:FootSplits = 0
  Set-Item -Path "function:Split-FooterPairs" -Value { $script:FootSplits++; & $footSplit @args }
  $footFirst = @(foreach ($r in (Get-FooterRows (Get-MenuFooter) 77 $script:MenuFooterAccent)) { @($r | ForEach-Object { $_[0] + ":" + ($_[1] -join ",") }) -join "" }) -join "`n"
  $script:FootSplits = 0
  $null = Get-MenuFooter
  $footAgain = @(foreach ($r in (Get-FooterRows (Get-MenuFooter) 77 $script:MenuFooterAccent)) { @($r | ForEach-Object { $_[0] + ":" + ($_[1] -join ",") }) -join "" }) -join "`n"
  Assert-Equal 0 $script:FootSplits "pied de page : pas recoupe d'une image a l'autre"
  Assert-Equal $footFirst $footAgain "pied de page : meme image"
  $script:Ink = $script:Palettes["light"]
  $footLight = Get-FooterRows (Get-MenuFooter) 77 $script:MenuFooterAccent
  Assert-Equal ($script:Ink.Dim -join ",") ($footLight[0][1][1] -join ",") "pied de page : theme change, nouvelles couleurs"
  $script:Ink = $footInk
  $footLang = $env:CLM_LANG
  $env:CLM_LANG = "fr"
  Assert-True ((Get-MenuFooter) -contains "quitter") "pied de page : langue changee, textes changes"
  $env:CLM_LANG = $footLang
} finally {
  Set-Item -Path "function:Split-FooterPairs" -Value $footSplit
  $script:Ink = $footInk
}
