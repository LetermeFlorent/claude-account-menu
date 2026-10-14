function Get-RowText {
  param($Row)
  $t = ""
  foreach ($s in $Row) { $t += $s[0] }
  return $t
}

$script:UiProgress = $null
Set-UiProgress "sauvegarde" 0
$script:UiProgress.Bar.Start = 0
Set-UiProgress "sauvegarde" 40 "3 fichiers"
Assert-Equal 40 $script:UiProgress.Bar.To "barre vers le nouveau pourcentage"
Assert-Equal "3 fichiers" $script:UiProgress.Detail "detail garde"
$t = Get-RowText (Get-ProgressRow 80 ((Get-NowMs) + 1000))
Assert-True ($t.StartsWith("  sauvegarde  ")) "libelle en tete"
Assert-True ($t -match "  40 %  3 fichiers$") ("pourcentage puis detail : " + $t)
Set-UiProgress "telechargement" -1 "2.1.3"
Assert-Equal "telechargement" $script:UiProgress.Label "nouveau libelle, nouvelle barre"
$t = Get-RowText (Get-ProgressRow 80 0)
Assert-True ($t -notmatch "%") "pas de pourcentage inconnu"
$script:UiQuit = $true
Assert-True ((Get-RowText (Get-ProgressRow 80 0)) -match "arret demande") "arret annonce"
$script:UiQuit = $false
$script:UiProgress = $null

$script:UiOn = $true
Write-TarProgress "archive" 50
Assert-Equal "archive 50" ($script:UiProgress.Label + " " + $script:UiProgress.Pct) "archive suivie dans l'interface"
Write-UpdateProgress "telechargement" "" " 12 %" "2.1.3"
Assert-Equal "12 2.1.3" ("" + $script:UiProgress.Pct + " " + $script:UiProgress.Detail) "mise a jour suivie dans l'interface"
$script:UiOn = $false
$script:UiProgress = $null

$script:UiKeys.Enqueue("k")
Assert-Equal "k" (Read-UiKey) "touche en attente lue d'abord"

$rows = Get-ListRows @("un", "deux") 1 @($true, $false)
Assert-Equal ("    " + [char]0x25A0 + "  un") (Get-RowText $rows[0]) "case cochee"
Assert-True ((Get-RowText $rows[1]).StartsWith("  " + $script:Mark + " " + [char]0x25A1 + "  deux")) "repere sur la case choisie"
$rows = Get-ListRows @("a", "b") 0
Assert-Equal "    2  b" (Get-RowText $rows[1]) "liste numerotee"
$p = Get-PageRows "Titre" $rows @("Echap", "annuler") "sous-titre"
Assert-Equal 10 $p.Count "page : titre, sous-titre, filets, lignes et pied"
Assert-Equal "  Titre" (Get-RowText $p[1]) "titre de page"
Assert-Equal "  Echap annuler" (Get-RowText $p[9]) "pied de page"

foreach ($f in Get-ChildItem -LiteralPath $bin -Filter "*.ps1") {
  $errs = $null
  $null = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errs)
  Assert-Equal 0 @($errs).Count ("syntaxe de " + $f.Name)
}
