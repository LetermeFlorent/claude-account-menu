. Import-ClmModule claude-ui-color-depth
Assert-Equal "none" (Get-ColorDepth "Linux" @{ NO_COLOR = "1"; COLORTERM = "truecolor" }) "couleurs : NO_COLOR coupe tout"
Assert-Equal "none" (Get-ColorDepth "Windows" @{ NO_COLOR = "x" }) "couleurs : NO_COLOR coupe aussi sous Windows"
Assert-Equal "truecolor" (Get-ColorDepth "Linux" @{ NO_COLOR = ""; COLORTERM = "truecolor"; TERM = "xterm" }) "couleurs : NO_COLOR vide ignoree"
Assert-Equal "truecolor" (Get-ColorDepth "MacOS" @{ COLORTERM = "24bit" }) "couleurs : COLORTERM 24bit"
Assert-Equal "truecolor" (Get-ColorDepth "Windows" @{}) "couleurs : console Windows en 24 bits"
Assert-Equal "truecolor" (Get-ColorDepth "MacOS" @{ TERM_PROGRAM = "iTerm.app"; TERM = "xterm-256color" }) "couleurs : iTerm2 en 24 bits"
Assert-Equal "truecolor" (Get-ColorDepth "Linux" @{ TERM = "xterm-direct" }) "couleurs : TERM direct en 24 bits"
Assert-Equal "256" (Get-ColorDepth "MacOS" @{ TERM_PROGRAM = "Apple_Terminal"; TERM = "xterm-256color" }) "couleurs : Terminal.app en 256"
Assert-Equal "16" (Get-ColorDepth "Linux" @{ TERM = "linux" }) "couleurs : console Linux en 16"
Assert-Equal "16" (Get-ColorDepth "Linux" @{ TERM = "xterm" }) "couleurs : xterm simple en 16"
Assert-Equal "none" (Get-ColorDepth "Linux" @{ TERM = "dumb" }) "couleurs : terminal muet sans couleur"

Assert-Equal ";38;2;1;2;3" (Get-ColorSgr @(1, 2, 3) "truecolor") "couleurs : sequence 24 bits"
Assert-Equal "" (Get-ColorSgr @(1, 2, 3) "none") "couleurs : rien sans couleur"
Assert-Equal ";38;5;196" (Get-ColorSgr @(255, 0, 0) "256") "couleurs : rouge en 256"
Assert-Equal ";38;5;16" (Get-ColorSgr @(0, 0, 0) "256") "couleurs : noir en 256"
Assert-Equal ";38;5;244" (Get-ColorSgr @(128, 128, 128) "256") "couleurs : gris en 256"
Assert-Equal ";31" (Get-ColorSgr @(200, 10, 20) "16") "couleurs : rouge proche en 16"
Assert-Equal ";32" (Get-ColorSgr @(10, 180, 30) "16") "couleurs : vert proche en 16"

foreach ($theme in @("dark", "light")) {
  $p = $script:Palettes[$theme]
  $roles = @(foreach ($k in @("Text", "Dim", "Empty", "Alert")) { ConvertTo-Ansi16 $p[$k] })
  Assert-Equal 4 (@($roles | Select-Object -Unique).Count) ("16 couleurs " + $theme + " : texte, attenue, vide et alerte distincts")
  foreach ($kind in @("5h", "7d")) {
    $lv = @(foreach ($c in $script:LevelSets[$theme][$kind]) { ConvertTo-Ansi16 $c })
    Assert-Equal 3 (@($lv | Select-Object -Unique).Count) ("16 couleurs " + $theme + " : trois niveaux " + $kind + " distincts")
    Assert-True ($lv -notcontains (ConvertTo-Ansi16 $p.Empty)) ("16 couleurs " + $theme + " : niveaux " + $kind + " distincts des cases vides")
  }
  $savedInk = $script:Ink
  $script:Ink = $p
  Assert-True (@("39", "2") -contains (ConvertTo-Ansi16 (Get-MixedRgb $p.Dim $p.Text 0.5))) ("16 couleurs " + $theme + " : gris melange range parmi les textes")
  $script:Ink = $savedInk
}
