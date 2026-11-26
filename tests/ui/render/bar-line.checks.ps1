function Get-LineBarText {
  param($Segs)
  return (@($Segs | ForEach-Object { $_[0] }) -join "")
}

function Get-LineUsage {
  param([double]$Pct, [int]$Room)
  $segs = New-Row
  Add-UsageSegs @{ Segs = $segs; Kind = "5h"; Tween = (New-Tween $Pct $Pct 0 0); Left = "3h29m"; Pace = $null; Cells = $script:BarCells; Now = 0; Wide = $true; Room = $Room }
  return ,$segs
}

$lineFull = [string][char]0x2501
$lineHole = [string][char]0x254C
$lineSep = Get-ClmText "ui.number.decimalSep"
Assert-True ($script:BarFull -ceq $lineFull -and $script:BarEmpty -ceq $lineHole) "barre fine : trait plein et trait tirete"
Assert-Equal "16 16 16" ("" + $script:BarCells + " " + (Get-MenuLayout 120 40 3).Cells + " " + (Get-MenuLayout 80 20 3).Cells) "barre fine : seize cases en vue complete et compacte"

$lineSegs = New-Row
Add-BarSegs $lineSegs "5h" 52.3 @(120, 110, 200) 16
Assert-Equal (($lineFull * 8) + ($lineHole * 8)) (Get-LineBarText $lineSegs) "barre fine a 52,3 % : huit traits pleins"
Assert-Equal "120,110,200" (@($lineSegs | Where-Object { $_[0].Contains($lineFull) } | ForEach-Object { $_[1] -join "," } | Select-Object -Unique) -join ";") "barre fine : une seule couleur pour la partie pleine"
Assert-Equal ($script:Ink.Cell -join ",") (@($lineSegs | Where-Object { $_[0].Contains($lineHole) } | ForEach-Object { $_[1] -join "," } | Select-Object -Unique) -join ";") "barre fine : partie vide en gris"

$line = Get-LineUsage 52.3 80
Assert-True ((Get-LineBarText $line).StartsWith("5h  " + ($lineFull * 8) + ($lineHole * 8) + "  52" + $lineSep + "3%")) "ligne a 52,3 % : barre puis pourcentage avec sa decimale"
Assert-Equal ($script:BarHues["5h"][1] -join ",") (@($line | Where-Object { $_[0].Contains($lineFull) })[0][1] -join ",") "ligne a 52,3 % : couleur du palier"
$line = Get-LineUsage 19 80
Assert-True ((Get-LineBarText $line).StartsWith("5h  " + ($lineFull * 3) + ($lineHole * 13) + "    19%")) "ligne a 19 % : pourcentage cale a droite, sans decimale"
Assert-Equal ($script:BarHues["5h"][0] -join ",") (@($line | Where-Object { $_[0].Contains($lineFull) })[0][1] -join ",") "ligne a 19 % : couleur du premier palier"
Assert-Equal ($script:Ink.Dim -join ",") (@($line | Where-Object { $_[0].Contains("3h29m") })[0][1] -join ",") "ligne large : remise a zero en gris a droite"
$line = Get-LineUsage 19 30
Assert-Equal ("5h  " + ($lineFull * 3) + ($lineHole * 13) + "    19%") (Get-LineBarText $line) "ligne etroite : remise a zero retiree"
