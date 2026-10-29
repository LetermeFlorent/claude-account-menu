$gateKept = @{ Gate = $script:InputGate; Settle = $script:InputSettleMs; Hold = $script:InputHoldMs; Repeat = $script:InputRepeatMs }
$script:InputSettleMs = 150
$script:InputHoldMs = 1100
$script:InputRepeatMs = 500

function New-GateKey {
  param([ConsoleKey]$Key, [int]$Char = 0)
  return New-Object System.ConsoleKeyInfo ([char]$Char), $Key, $false, $false, $false
}

function Reset-TestGate {
  param([object[]]$Drained = @(), [int[]]$Down = @())
  $script:InputGate = @{ OpenAt = [double]::MinValue; Held = @{} }
  foreach ($e in $Drained) { Add-StaleInput $e 900 }
  Open-InputGate 1000 $Down
}

try {
  $enter = New-GateKey ([ConsoleKey]::Enter) 13
  $one = New-GateKey ([ConsoleKey]::D1) 49
  Assert-Equal 13 (Get-InputKeyCode 0 13) "porte d'entree : retour chariot sans touche lu comme Entree"
  Assert-Equal 13 (Get-InputKeyCode 0 10) "porte d'entree : saut de ligne sans touche lu comme Entree"
  Assert-Equal 49 (Get-InputKeyCode 49 49) "porte d'entree : touche connue gardee"
  Reset-TestGate
  Assert-True (-not (Test-FreshInput $enter 1100)) "porte d'entree : Entree juste apres l'affichage ignoree"
  Assert-True (-not (Test-FreshInput $enter 1500)) "porte d'entree : repetition de cette Entree ignoree"
  Assert-True (-not (Test-FreshInput @{ Mouse = "double"; X = 1; Y = 4 } 1120)) "porte d'entree : double clic juste apres l'affichage ignore"
  Assert-True (Test-FreshInput (New-GateKey ([ConsoleKey]::C) 3) 1010) "porte d'entree : Ctrl+C toujours lu"
  Reset-TestGate @($enter)
  Assert-True (-not (Test-FreshInput $enter 1300)) "porte d'entree : Entree tenue au lancement, repetition ignoree"
  Assert-True (-not (Test-FreshInput $enter 1700)) "porte d'entree : repetitions suivantes ignorees"
  Assert-True (-not (Test-FreshInput $enter 2150)) "porte d'entree : repetition lente encore ignoree"
  Assert-True (-not (Test-FreshInput @{ KeyUp = 13 } 2200)) "porte d'entree : touche relachee, rien a lire"
  Assert-True (Test-FreshInput $enter 2250) "porte d'entree : Entree pressee apres le relachement lue"
  Reset-TestGate @($enter)
  $null = Test-FreshInput $enter 1300
  Assert-True (Test-FreshInput $enter 1900) "porte d'entree : pression 600 ms apres la derniere repetition lue"
  Reset-TestGate @($enter)
  Assert-True (Test-FreshInput $enter 2200) "porte d'entree : Entree pressee longtemps apres, sans relachement vu, lue"
  Reset-TestGate @($enter, @{ KeyUp = 13 })
  Assert-True (Test-FreshInput $enter 1200) "porte d'entree : Entree relachee avant l'affichage, nouvelle pression lue"
  Reset-TestGate @() @(13)
  Assert-True (-not (Test-FreshInput $enter 1900)) "porte d'entree : Entree enfoncee a l'affichage, repetition ignoree"
  Reset-TestGate @($one)
  Assert-True (-not (Test-FreshInput $one 1200)) "porte d'entree : chiffre tenu au lancement ignore"
  Assert-True (Test-FreshInput $enter 1200) "porte d'entree : autre touche lue"
  Assert-True (Test-FreshInput @{ Mouse = "click"; X = 1; Y = 4 } 1200) "porte d'entree : clic apres l'affichage lu"
  $down = New-GateKey ([ConsoleKey]::DownArrow)
  Reset-TestGate @($down)
  Assert-True ((Test-FreshInput $down 1200) -and (Test-FreshInput $down 1230)) "porte d'entree : molette et fleches jamais retenues"
  Reset-TestGate
  Assert-True (Test-FreshInput $enter 1200) "porte d'entree : rien en attente, Entree lue"
} finally {
  $script:InputGate = $gateKept.Gate
  $script:InputSettleMs = $gateKept.Settle
  $script:InputHoldMs = $gateKept.Hold
  $script:InputRepeatMs = $gateKept.Repeat
}
