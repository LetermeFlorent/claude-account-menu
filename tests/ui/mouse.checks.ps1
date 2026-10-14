if ($script:OsName -eq "Windows") {
  Add-Type -TypeDefinition $script:ConInSource
  Assert-True ([bool]("ClmConIn" -as [type])) "lecteur de souris compile"
}

Assert-Equal "Enter" (New-KeyInfo "Entree ou 1-9").Key "Entree du pied de page"
Assert-Equal "Escape" (New-KeyInfo "Echap").Key "Echap du pied de page"
Assert-Equal "Escape" (New-KeyInfo "autre touche").Key "autre touche annule"
Assert-Equal " " (New-KeyInfo "Espace").KeyChar "Espace du pied de page"
Assert-Equal "a" (New-KeyInfo "a").KeyChar "lettre du pied de page"
Assert-Equal "A" (New-KeyInfo "a").Key "touche de la lettre"
Assert-Null (New-KeyInfo "fleche") "nom inconnu"

$foot = Get-FooterRows $script:MenuFooter 100
$rows = @((New-Row), $foot[0])
Assert-Equal "Entree" (Get-FooterKeyAt $rows 3 1) "clic sur Entree"
Assert-Equal "a" (Get-FooterKeyAt $rows 19 1) "clic sur le libelle ajouter"
Assert-Null (Get-FooterKeyAt $rows 3 0) "clic hors du pied de page"
Assert-Null (Get-FooterKeyAt $rows 3 5) "clic sous l'ecran"

Assert-Equal "UpArrow" (ConvertFrom-MouseEvent @(2, 0, 0, 3, 120) $rows).Key "molette vers le haut"
Assert-Equal "DownArrow" (ConvertFrom-MouseEvent @(2, 0, 0, 3, -120) $rows).Key "molette vers le bas"
Assert-Equal "a" (ConvertFrom-MouseEvent @(2, 19, 1, 1, 0) $rows).KeyChar "clic sur une touche du pied"
Assert-Null (ConvertFrom-MouseEvent @(2, 19, 1, 2, 0) $rows) "double clic sur le pied, une seule action"
Assert-Equal "a" (ConvertFrom-MouseEvent @(2, 19, 11, 1, 0) $rows 10).KeyChar "clic decale du haut de la fenetre"
$m = ConvertFrom-MouseEvent @(2, 5, 0, 1, 0) $rows
Assert-Equal "click 5 0" ($m.Mouse + " " + $m.X + " " + $m.Y) "clic transmis au menu"

$st = @{ Sel = 0; Hit = @{ Start = 4; Per = 5; Top = 1; Last = 3 } }
Assert-Equal -1 (Get-EntryAt $st 3) "clic au-dessus des comptes"
Assert-Equal 1 (Get-EntryAt $st 4) "premiere ligne du premier compte visible"
Assert-Equal 2 (Get-EntryAt $st 13) "derniere ligne du second compte visible"
Assert-Equal -1 (Get-EntryAt $st 14) "clic sous les comptes"
$a = Get-MenuMouseAction $st @{ Mouse = "click"; Y = 9 }
Assert-Equal "select 2" ($a.Name + " " + $a.Index) "clic choisit le compte"
$a = Get-MenuMouseAction $st @{ Mouse = "double"; Y = 9 }
Assert-Equal "select" $a.Name "double clic sur un autre compte, choix seulement"
$st.Sel = 2
$a = Get-MenuMouseAction $st @{ Mouse = "double"; Y = 9 }
Assert-Equal "pick 2" ($a.Name + " " + $a.Index) "double clic sur le compte choisi, lancement"
Assert-Equal "none" (Get-MenuMouseAction $st @{ Mouse = "click"; Y = 1 }).Name "clic sur l'en-tete sans effet"
