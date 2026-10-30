$gradKept = (Get-Item "function:Get-LerpRgb").ScriptBlock
$script:GradLerps = 0

function Get-GradText {
  param($Segs)
  return (@($Segs | ForEach-Object { $_[0] + ":" + ($_[1] -join ",") }) -join " ")
}

function New-GradBar {
  param([string]$Kind, [double]$Pct, $Base)
  $segs = New-Row
  Add-BarSegs $segs $Kind $Pct $Base 20
  return ,$segs
}

try {
  $plain = Get-GradText (New-GradBar "5h" 55 @(200, 120, 40))
  Set-Item -Path "function:Get-LerpRgb" -Value { $script:GradLerps++; & $gradKept @args }
  $script:BarGradients = @{}
  $first = Get-GradText (New-GradBar "5h" 55 @(200, 120, 40))
  $lerps = $script:GradLerps
  $again = Get-GradText (New-GradBar "5h" 55 @(200, 120, 40))
  Assert-Equal $plain $first "degrade en cache : meme barre qu'avant"
  Assert-Equal $first $again "degrade en cache : meme barre au deuxieme dessin"
  Assert-Equal 11 $lerps "degrade : une teinte par case pleine au premier dessin"
  Assert-Equal $lerps $script:GradLerps "degrade : aucune teinte recalculee pour la meme barre"
  $null = New-GradBar "5h" 55 @(40, 120, 200)
  Assert-Equal (2 * $lerps) $script:GradLerps "degrade : autre couleur, degrade refait"
  $null = New-GradBar "7d" 55 @(40, 120, 200)
  $null = New-GradBar "5h" 60 @(40, 120, 200)
  Assert-True ($script:GradLerps -gt 2 * $lerps) "degrade : autre largeur ou autre niveau, degrade refait"
} finally {
  Set-Item -Path "function:Get-LerpRgb" -Value $gradKept
}
