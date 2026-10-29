$ctlEsc = [string][char]27
$ctlBell = [string][char]7
$ctlAny = '[\x00-\x1F\x7F-\x9F]'

foreach ($ctlCode in 0..31) {
  $ctlName = "nom : code C0 0x" + $ctlCode.ToString("X2") + " retire"
  Assert-Equal "ab" (ConvertTo-AccountLabel ("a" + [char]$ctlCode + "b")) $ctlName
}
Assert-Equal "ab" (ConvertTo-AccountLabel ("a" + [char]0x7F + "b")) "nom : code DEL 0x7F retire"
foreach ($ctlCode in 0x80..0x9F) {
  $ctlName = "nom : code C1 0x" + $ctlCode.ToString("X2") + " retire"
  Assert-Equal "ab" (ConvertTo-AccountLabel ("a" + [char]$ctlCode + "b")) $ctlName
}

$ctlAnsi = ConvertTo-AccountLabel ($ctlEsc + "[31mtexte" + $ctlEsc + "[0m")
Assert-True ($ctlAnsi -notmatch $ctlAny) "nom : sequence ANSI de couleur sans caractere de controle"
Assert-True ($ctlAnsi.Contains("texte")) "nom : sequence ANSI de couleur, le texte reste"
$ctlOsc = ConvertTo-AccountLabel ($ctlEsc + "]0;titre" + $ctlBell + "suite")
Assert-True ($ctlOsc -notmatch $ctlAny) "nom : sequence OSC sans caractere de controle"
Assert-True ($ctlOsc.Contains("suite")) "nom : sequence OSC, le texte reste"
$ctlCsi = ConvertTo-AccountLabel ([string][char]0x9B + "31mtexte" + [char]0x9B + "0m")
Assert-True ($ctlCsi -notmatch $ctlAny) "nom : introducteur CSI 0x9B sans caractere de controle"
Assert-True ($ctlCsi.Contains("texte")) "nom : introducteur CSI 0x9B, le texte reste"

Assert-Equal 39 (ConvertTo-AccountLabel ("n" * 39)).Length "nom : 39 caracteres gardes"
Assert-Equal 40 (ConvertTo-AccountLabel ("n" * 40)).Length "nom : 40 caracteres gardes"
Assert-Equal 40 (ConvertTo-AccountLabel ("n" * 41)).Length "nom : 41 caracteres coupes a 40"
Assert-Equal ("n" * 40) (ConvertTo-AccountLabel ("n" * 41)) "nom : 41 caracteres, les 40 premiers gardes"
Assert-Equal ("n" * 39) (ConvertTo-AccountLabel (("n" * 39) + " " + ("m" * 5))) "nom : coupe sur une espace, espace finale retiree"
Assert-Equal 40 (ConvertTo-AccountLabel ($ctlEsc + [char]0x85 + ("n" * 41))).Length "nom : controles retires avant de couper a 40"

$ctlLong = ConvertTo-AccountLabel ("n" * 100000)
Assert-Equal 40 $ctlLong.Length "nom : 100000 caracteres coupes a 40"
$ctlLongMixed = ConvertTo-AccountLabel (("n" + $ctlEsc) * 50000)
Assert-Equal 40 $ctlLongMixed.Length "nom : 100000 caracteres avec controles coupes a 40"
Assert-True ($ctlLongMixed -notmatch $ctlAny) "nom : 100000 caracteres avec controles, aucun controle"

$ctlOnlyC1 = -join (0x80..0x9F | ForEach-Object { [char]$_ })
Assert-Equal "" (ConvertTo-AccountLabel $ctlOnlyC1) "nom : que du C1, vide"
Assert-Equal "" (ConvertTo-AccountLabel (-join (0..31 | ForEach-Object { [char]$_ }))) "nom : que du C0, vide"
