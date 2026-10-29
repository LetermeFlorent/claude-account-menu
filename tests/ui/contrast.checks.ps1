. Import-ClmModule claude-ui-contrast, claude-ui-palette

$black = @(0, 0, 0)
$white = @(255, 255, 255)
$mid = @(120, 110, 200)
Assert-Equal "21" ([math]::Round((Get-ContrastRatio $black $white), 2)) "ratio noir sur blanc"
Assert-Equal "1" (Get-ContrastRatio $mid $mid) "ratio d'une couleur sur elle-meme"
Assert-Equal (Get-ContrastRatio $mid $white) (Get-ContrastRatio $white $mid) "ratio independant de l'ordre"

Assert-Equal "dark" (Get-BackgroundTheme @(12, 12, 12)) "theme du fond 12,12,12"
Assert-Equal "light" (Get-BackgroundTheme @(250, 250, 250)) "theme du fond 250,250,250"
Assert-Equal "dark" (Get-BackgroundTheme @(0, 43, 54)) "theme du fond 0,43,54"
Assert-Equal "light" (Get-BackgroundTheme @(253, 246, 227)) "theme du fond 253,246,227"
Assert-Equal "" (Get-BackgroundTheme $null) "theme d'un fond absent"

$themeNames = @{ light = "clair"; dark = "sombre" }
$roles = @(
  @{ Key = "Text"; Min = 4.5 }, @{ Key = "Dim"; Min = 4.5 }, @{ Key = "Alert"; Min = 4.5 },
  @{ Key = "Empty"; Min = 3 }, @{ Key = "Cell"; Min = 3 }
)
foreach ($theme in @("light", "dark")) {
  $palette = $script:Palettes[$theme]
  foreach ($role in $roles) {
    $ratio = [math]::Round((Get-ContrastRatio $palette[$role.Key] $palette.Bg), 2)
    Assert-True ($ratio -ge $role.Min) ("contraste " + $themeNames[$theme] + " " + $role.Key + " " + $ratio + " >= " + $role.Min)
  }
  foreach ($kind in @("5h", "7d")) {
    for ($i = 0; $i -lt 3; $i++) {
      $ratio = [math]::Round((Get-ContrastRatio $script:LevelSets[$theme][$kind][$i] $palette.Bg), 2)
      Assert-True ($ratio -ge 4.5) ("contraste " + $themeNames[$theme] + " niveau " + $kind + " " + $i + " " + $ratio + " >= 4.5")
    }
  }
}
