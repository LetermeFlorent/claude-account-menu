. Import-ClmModule claude-ui-width

$ideo = [string][char]0x65E5 + [char]0x672C + [char]0x8A9E
$emoji = [char]::ConvertFromUtf32(0x1F600)
$combined = "e" + [char]0x0301

Assert-Equal 0 (Get-DisplayWidth -Text "") "largeur : chaine vide"
Assert-Equal 0 (Get-DisplayWidth -Text ([string]$null)) "largeur : valeur nulle convertie"
Assert-Equal 5 (Get-DisplayWidth -Text "hello") "largeur : ascii une case par lettre"
Assert-Equal 1 (Get-DisplayWidth -Text ([string][char]0x2500)) "largeur : trait de cadre"
Assert-Equal 1 (Get-DisplayWidth -Text ([string][char]0x25A0)) "largeur : carre de barre"
Assert-Equal 1 (Get-DisplayWidth -Text ([string][char]0x2502)) "largeur : trait vertical"
Assert-Equal 6 (Get-DisplayWidth -Text $ideo) "largeur : ideogrammes sur deux cases"
Assert-Equal 10 (Get-DisplayWidth -Text ("ab" + $ideo + "cd")) "largeur : texte mixte"
Assert-Equal 2 (Get-DisplayWidth -Text ([string][char]0xD55C)) "largeur : syllabe hangul"
Assert-Equal 2 (Get-DisplayWidth -Text ([string][char]0xFF21)) "largeur : A pleine chasse"
Assert-Equal 1 (Get-DisplayWidth -Text $combined) "largeur : lettre et accent combinant"
Assert-Equal 0 (Get-DisplayWidth -Text ([string][char]0x200D)) "largeur : liant de largeur nulle"
Assert-Equal 0 (Get-DisplayWidth -Text ([string][char]0xFE0F)) "largeur : selecteur de variation"
Assert-Equal 0 (Get-DisplayWidth -Text ([string][char]0x07)) "largeur : caractere de controle"
Assert-Equal 2 (Get-DisplayWidth -Text $emoji) "largeur : emoji en paire de substitution"
Assert-Equal 2 (Get-DisplayWidth -Text ([string][char]0x2705)) "largeur : emoji du plan de base"
Assert-Equal 1 (Get-DisplayWidth -Text ([char]::ConvertFromUtf32(0x1D400))) "largeur : supplementaire etroit"
Assert-Equal 1 (Get-DisplayWidth -Text ([string][char]0xD83D)) "largeur : substitut haut isole"
Assert-Equal 3 (Get-DisplayWidth -Text ("a" + $emoji)) "largeur : emoji apres une lettre"
Assert-Equal 3 (Get-DisplayWidth -Text ("abc" + [char]10)) "largeur : saut de ligne final sans case"
Assert-Equal 2 (Get-DisplayWidth -Text ("a" + [char]0x00AD + "b")) "largeur : trait d union conditionnel invisible"
Assert-Equal 2 (Get-DisplayWidth -Text ([string][char]0x1100 + [char]0x1161)) "largeur : syllabe hangul en jamos"

Assert-Equal "" (Limit-DisplayText -Text "abc" -Max 0) "coupe : budget nul"
Assert-Equal "" (Limit-DisplayText -Text "abc" -Max -3) "coupe : budget negatif"
Assert-Equal "abc" (Limit-DisplayText -Text "abcdef" -Max 3) "coupe : ascii tronque"
Assert-Equal "abc" (Limit-DisplayText -Text "abc" -Max 10) "coupe : texte qui tient reste intact"
Assert-Equal ([string][char]0x65E5 + [char]0x672C) (Limit-DisplayText -Text $ideo -Max 5) "coupe : budget impair avant l ideogramme"
Assert-Equal $ideo (Limit-DisplayText -Text $ideo -Max 6) "coupe : ideogrammes qui tiennent"
Assert-Equal "" (Limit-DisplayText -Text $emoji -Max 1) "coupe : paire de substitution jamais coupee"
Assert-Equal $emoji (Limit-DisplayText -Text $emoji -Max 2) "coupe : emoji qui tient"
Assert-Equal $combined (Limit-DisplayText -Text ($combined + "x") -Max 1) "coupe : accent garde avec sa lettre"
Assert-Equal ("a" + $emoji) (Limit-DisplayText -Text ("a" + $emoji + "b") -Max 3) "coupe : emoji garde quand il tient"
