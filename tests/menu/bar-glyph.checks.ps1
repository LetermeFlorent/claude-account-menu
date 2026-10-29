function Get-GlyphText {
  param($Segs)
  return (@($Segs | ForEach-Object { $_[0] }) -join "")
}

$full = [string][char]0x25A0
$empty = [string][char]0x25A1
$segs = New-Row
Add-BarSegs $segs "5h" 50 @(120, 110, 200) 20
Assert-Equal (($full * 9) + [char]0x25AA + ($empty * 10)) (Get-GlyphText $segs) "barre sans couleur : cases vides dessinees autrement que les pleines"
Assert-True ($script:BarEmpty -cne $script:BarFull -and $script:BarEmpty -cne $script:BarHalf) "case vide : glyphe a part"
$segs = New-Row
Add-ShimmerSegs $segs 20 600
Assert-Equal ($empty * 20) (Get-GlyphText $segs) "scintillement : cases vides"
$segs = New-Row
Add-ProgressSegs $segs 25 20 0
Assert-Equal (($full * 4) + [char]0x25AA + ($empty * 15)) (Get-GlyphText $segs) "progression : cases restantes vides"
