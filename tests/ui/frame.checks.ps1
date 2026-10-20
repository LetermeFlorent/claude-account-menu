$e = $script:Esc
$segs = @(@("ab", @(200, 10, 20), $false), @("", @(9, 9, 9), $false), @("cd", @(1, 2, 3), $true))
Assert-Equal ($e + "[0;38;2;200;10;20mab" + $e + "[0;1;38;2;1;2;3mcd" + $e + "[0m") (ConvertTo-LineText $segs 80) "ligne rendue en couleurs"
$cut = (ConvertTo-LineText @(@("abcdef", @(1, 1, 1), $false), @("gh", @(1, 1, 1), $false)) 4) -replace "$e\[[0-9;]*m", ""
Assert-Equal "abcd" $cut "ligne coupee a la largeur"
Assert-Equal ($e + "[0;38;2;130;130;130mx" + $e + "[0m") (ConvertTo-LineText @(, @("x", @(250, 250, 250), $false)) 9 0.5 @(10, 10, 10)) "fondu vers le fond"

$a = [string[]]@("un", "deux", "trois")
Assert-Equal "" (Get-FrameUpdate $a $a) "image identique, rien a ecrire"
Assert-Equal ($e + "[2;1HDEUX" + $e + "[K") (Get-FrameUpdate ([string[]]@("un", "DEUX", "trois")) $a) "seule la ligne changee est reecrite"
Assert-Equal ($e + "[3;1H" + $e + "[2K") (Get-FrameUpdate ([string[]]@("un", "deux")) $a) "ligne en trop effacee"
Assert-Equal ($e + "[1;1Hun" + $e + "[K" + $e + "[2;1Hdeux" + $e + "[K") (Get-FrameUpdate ([string[]]@("un", "deux")) $null) "premiere image complete"

$side = [string][char]0x2502
$content = New-Object 'System.Collections.Generic.List[object]'
$content.Add((New-Row))
$content.Add([System.Collections.Generic.List[object]]@(, @("  titre", @(200, 200, 200), $true)))
$content.Add([System.Collections.Generic.List[object]]@(@("  ", @(1, 1, 1), $false), @("Entree", @(1, 1, 1), $false, "Entree")))
$content.Add([System.Collections.Generic.List[object]]@(, @("  message beaucoup trop long", @(1, 1, 1), $false)))
$framed = Get-FramedRows $content @(1.0, 0.5, 1.0, 1.0) 12
$ft = @(foreach ($r in $framed) { $t = ""; foreach ($s in $r) { $t += $s[0] }; $t })
Assert-Equal 5 $framed.Count "cadre : la marge du haut devient le bord, bord du bas ajoute"
Assert-Equal ([string][char]0x256D + ($script:Rule * 12) + [string][char]0x256E) $ft[0] "cadre : bord du haut arrondi"
Assert-Equal ([string][char]0x2570 + ($script:Rule * 12) + [string][char]0x256F) $ft[4] "cadre : bord du bas arrondi"
Assert-Equal ($side + "  titre     " + $side) $ft[1] "cadre : rangee bordee et completee"
Assert-Equal ($side + "  message be" + $side) $ft[3] "cadre : rangee trop longue coupee avant le bord"
Assert-Equal ((Get-FadedRgb @(200, 200, 200) 0.5 @(0, 0, 0)) -join " ") "100 100 100" "fondu calcule vers le fond"
Assert-Equal ((Get-FadedRgb @(200, 200, 200) 0.5 $script:Ink.Bg) -join " ") ($framed[1][1][1] -join " ") "cadre : fondu de la rangee sur son texte"
Assert-Equal ($script:Ink.Empty -join " ") ($framed[1][0][1] -join " ") "cadre : bord jamais estompe"
Assert-Equal "200 200 200" ($content[1][0][1] -join " ") "cadre : rangee d'origine intacte"
Assert-Equal "Entree" (Get-FooterKeyAt $framed 3 2) "cadre : touche du pied cliquable apres le bord"
Assert-Null (Get-FooterKeyAt $framed 0 2) "cadre : clic sur le bord sans effet"
