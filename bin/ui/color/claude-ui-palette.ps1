$script:LevelSets = @{
  "light" = @{
    "5h" = @(@(110, 99, 196), @(162, 81, 167), @(200, 60, 95))
    "7d" = @(@(73, 121, 105), @(147, 103, 54), @(183, 80, 80))
  }
  "dark" = @{
    "5h" = @(@(123, 113, 201), @(173, 95, 178), @(206, 82, 113))
    "7d" = @(@(83, 137, 119), @(185, 130, 68), @(190, 97, 97))
  }
}
$script:Levels = $script:LevelSets["dark"]
$script:Palettes = @{
  "light" = @{ Text = @(0, 0, 0); Dim = @(120, 112, 100); Empty = @(154, 138, 115); Cell = @(154, 138, 115); Alert = @(183, 80, 80); Bg = @(250, 250, 250) }
  "dark" = @{ Text = @(232, 234, 237); Dim = @(150, 150, 150); Empty = @(98, 98, 104); Cell = @(226, 229, 234); Alert = @(220, 100, 100); Bg = @(12, 12, 12) }
}

function Use-Palette {
  param([string]$Name)
  if (-not $script:Palettes.ContainsKey($Name)) { $Name = "dark" }
  $script:Ink = $script:Palettes[$Name]
  $script:Levels = $script:LevelSets[$Name]
}
