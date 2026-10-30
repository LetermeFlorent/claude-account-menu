. (Join-Path $bin "menu/loop/claude-menu-loop.ps1")
. (Join-Path $bin "menu/startup/claude-menu-startup.ps1")
. (Join-Path $PSScriptRoot "fresh-input-fakes.ps1")

$repeats = @(,@(900, "Enter"))
for ($t = 1200; $t -le 1600; $t += 40) { $repeats += ,@($t, "Enter") }
$repeats += ,@(2800, "Enter")
$repeats += ,@(5000, "Escape")

Install-TimelineFakes
try {
  $r = Invoke-TimelineMenu 1 @(@(900, "Enter"), @(1040, "Enter"), @(1300, "Enter"), @(1330, "Enter"), @(3000, "Escape"))
  Assert-Null $r.Label "entree fraiche : un seul compte, Entree du lancement puis repetitions, aucun compte ouvert"

  $r = Invoke-TimelineMenu 1 @(@(900, "Enter"), @(1300, "Enter"), @(1350, "up:13"), @(1500, "Enter"), @(5000, "Escape"))
  Assert-Equal "a" $r.Label "entree fraiche : Entree relachee puis pressee de nouveau, compte ouvert"
  Assert-Equal "dans les bornes" (Get-BoundText $r.End -Min 1500) "entree fraiche : Entree relachee, ouverture pas avant la nouvelle pression"

  $r = Invoke-TimelineMenu 1 $repeats
  Assert-Equal "a" $r.Label "entree fraiche : sans relachement vu, nouvelle Entree apres la pause, compte ouvert"
  Assert-Equal "dans les bornes" (Get-BoundText $r.End -Min 2800 -Max 2900) "entree fraiche : sans relachement vu, ouverture a la nouvelle Entree"

  $r = Invoke-TimelineMenu 1 @(@(1050, "Enter"), @(1100, "Digit1"), @(3000, "Escape"))
  Assert-Null $r.Label "entree fraiche : Entree et chiffre juste apres l'affichage ignores"

  $r = Invoke-TimelineMenu 1 @(@(1300, "Enter"), @(5000, "Escape"))
  Assert-Equal "a" $r.Label "entree fraiche : Entree franche apres l'affichage, compte ouvert"
  Assert-Equal "dans les bornes" (Get-BoundText $r.End -Max 1399) "entree fraiche : Entree franche, reponse sans lenteur"

  $r = Invoke-TimelineMenu 1 @(@(1300, "Enter"), @(1900, "Enter"), @(5000, "Escape")) @(13)
  Assert-Equal "a" $r.Label "entree fraiche : sans sonde clavier, Entree supposee tenue a l'affichage, premiere pression ignoree"
  Assert-Equal "dans les bornes" (Get-BoundText $r.End -Min 1900 -Max 2000) "entree fraiche : sans sonde clavier, ouverture a la seconde pression"

  $r = Invoke-TimelineMenu 1 @(@(900, "Digit1"), @(1300, "Digit1"), @(3000, "Escape"))
  Assert-Null $r.Label "entree fraiche : chiffre 1 du lancement puis repetition, aucun compte ouvert"

  $r = Invoke-TimelineMenu 1 @(@(900, "Digit1"), @(1300, "Digit1"), @(1350, "up:49"), @(1500, "Digit1"), @(5000, "Escape"))
  Assert-Equal "a" $r.Label "entree fraiche : chiffre 1 relache puis presse de nouveau, compte ouvert"
  Assert-Equal "dans les bornes" (Get-BoundText $r.End -Min 1500) "entree fraiche : chiffre 1 relache, ouverture pas avant la nouvelle pression"

  $r = Invoke-TimelineMenu 1 @(@(900, "click"), @(910, "double"), @(1300, "double"), @(3000, "Escape"))
  Assert-Null $r.Label "entree fraiche : double clic seul apres des clics avant l'affichage, aucun compte ouvert"

  $r = Invoke-TimelineMenu 1 @(@(900, "click"), @(910, "double"), @(1300, "click"), @(1350, "double"), @(5000, "Escape"))
  Assert-Equal "a" $r.Label "entree fraiche : clic puis double clic apres l'affichage, compte ouvert"

  $r = Invoke-TimelineMenu 1 @(@(1300, "Down"), @(1400, "Up"), @(3000, "Escape"))
  Assert-Null $r.Label "entree fraiche : molette (fleches bas puis haut) n'ouvre aucun compte"

  $r = Invoke-TimelineMenu 1 @(@(1050, "CtrlC"), @(5000, "Escape"))
  Assert-Null $r.Label "entree fraiche : Ctrl+C dans la fenetre d'attente, aucun compte"
  Assert-Equal "dans les bornes" (Get-BoundText $r.End -Max 1200) "entree fraiche : Ctrl+C dans la fenetre d'attente, menu ferme aussitot"
  Assert-True (-not $r.UiOn) "entree fraiche : Ctrl+C, ecran rendu"

  Start-TimelineCase 1
  $script:MenuState = New-MenuState @(Get-Accounts) (Get-NowMs) $false 0
  Add-TimelineEvents @(,@(1000, "Enter"))
  $act = Read-MenuAction $script:MenuState
  Assert-Equal "none" $act.Name "entree fraiche : etat de menu jamais ouvert, Entree en attente ignoree"
  Assert-Equal "draw" ($script:TimelineLog | Select-Object -First 1) "entree fraiche : etat de menu jamais ouvert, affichage avant la lecture"
  Assert-Equal 0 $script:TimelineEvents.Count "entree fraiche : etat de menu jamais ouvert, Entree videe"
  Assert-Equal $true $script:MenuState.Opened "entree fraiche : etat de menu jamais ouvert, marque ouvert apres l'affichage"
} finally {
  Restore-TimelineFakes
}
Assert-Equal "reste : " (Get-TimelineLeftovers) "entree fraiche : fonctions et alias rendus"
