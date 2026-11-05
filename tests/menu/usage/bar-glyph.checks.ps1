function Get-GlyphText {
  param($Segs)
  return (@($Segs | ForEach-Object { $_[0] }) -join "")
}

$full = [string][char]0x25A0
$hole = [string][char]0x25A1
$half = [string][char]0x25AA
Assert-True ($script:BarEmpty -ceq $full -and $script:BarFull -ceq $full -and $script:BarHalf -ceq $half) "cases : memes carres que la barre de statut"
$segs = New-Row
Add-BarSegs $segs "5h" 50 @(120, 110, 200) 20
Assert-Equal ($full * 20) (Get-GlyphText $segs) "barre a 50 % : dix cases pleines sans case reduite"
Assert-Equal 10 (@($segs | Where-Object { ($_[1] -join ",") -eq ($script:Ink.Cell -join ",") } | ForEach-Object { $_[0].Length }) | Measure-Object -Sum).Sum "barre a 50 % : dix cases vides a la couleur des cases vides"
$segs = New-Row
Add-BarSegs $segs "5h" 47.5 @(120, 110, 200) 20
Assert-Equal (($full * 9) + $half + ($full * 10)) (Get-GlyphText $segs) "case a moitie pleine : petit carre, comme la barre de statut"
$segs = New-Row
Add-ProgressSegs $segs 25 20 0
Assert-Equal ($full * 20) (Get-GlyphText $segs) "progression : cases restantes vides"
$bgDepth = $script:UiColorDepth
try {
  $env:NO_COLOR = "1"
  $script:UiColorDepth = "none"
  . (Get-ClmModulePath "claude-ui-bars")
  Assert-Equal $hole $script:BarEmpty "sans couleur : cases vides dessinees autrement que les pleines"
} finally {
  Remove-Item Env:\NO_COLOR -ErrorAction SilentlyContinue
  $script:UiColorDepth = $bgDepth
  . (Get-ClmModulePath "claude-ui-bars")
}
