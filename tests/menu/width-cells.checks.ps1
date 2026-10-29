$wideLabel = [string][char]0x4E2D + [char]0x6587
$accentLabel = "caf" + [char]0x00E9 + " " + [char]0x00E0
$txt = $script:Ink.Text
Assert-Equal 4 (Get-SegsLength @(, @($wideLabel, $txt, $false))) "largeur en cases : libelle large sur deux cases par signe"
Assert-Equal 6 (Get-SegsLength @(, @($accentLabel, $txt, $false))) "largeur en cases : libelle accentue une case par lettre"
Assert-Equal 9 (Get-SegsLength @(@("ab", $txt, $false), @($wideLabel, $txt, $false), @($accentLabel, $txt, $false))) "largeur en cases : somme des segments"

$row = New-Row
$row.Add(@("ab", $txt, $false))
Add-RightSegs $row 20 @(, @($wideLabel, $txt, $false))
Assert-Equal 20 (Get-SegsLength $row) "pied de carte : libelle large aligne sur le bord droit"
$row = New-Row
$row.Add(@($accentLabel, $txt, $false))
Add-RightSegs $row 20 @(, @("Max", $txt, $false))
Assert-Equal 20 (Get-SegsLength $row) "pied de carte : libelle accentue aligne sur le bord droit"
$row = New-Row
$row.Add(@("ab", $txt, $false))
Add-RightSegs $row 7 @(, @($wideLabel, $txt, $false))
Assert-Equal 2 (Get-SegsLength $row) "pied de carte : libelle large trop etroit retire"

function Get-PaintedWidth {
  param([object[]]$Segs)
  $text = (Write-Segs $Segs 6>&1 | Out-String).TrimEnd("`r", "`n")
  return Get-DisplayWidth ($text -replace ([string][char]27 + "\[[0-9;]*m"), "")
}
Assert-Equal $script:ViewWidth (Get-PaintedWidth @(, @("abc", $txt, $false))) "ligne de vue : ascii complete jusqu'a la largeur"
Assert-Equal $script:ViewWidth (Get-PaintedWidth @(, @($wideLabel, $txt, $false))) "ligne de vue : libelle large complete en cases"
Assert-Equal $script:ViewWidth (Get-PaintedWidth @(, @($accentLabel, $txt, $false))) "ligne de vue : libelle accentue complete en cases"
