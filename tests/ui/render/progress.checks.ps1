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
Assert-True ((Get-RowText (Get-ProgressRow 80 0)) -match [regex]::Escape((Get-ClmText "ui.progress.stopping"))) "arret annonce"
$script:UiQuit = $false
$script:UiProgress = $null

$script:UiOn = $true
Write-TarProgress "archive" 50
Assert-Equal "archive 50" ($script:UiProgress.Label + " " + $script:UiProgress.Pct) "archive suivie dans l'interface"
$script:UiOn = $false
$script:UiProgress = $null

$script:UiKeys.Enqueue("k")
Assert-Equal "k" (Read-UiKey) "touche en attente lue d'abord"

$workKept = @{}
foreach ($n in @("Hide-Screen", "Show-WorkPage")) { $workKept[$n] = (Get-Item ("function:" + $n)).ScriptBlock }
try {
  function Hide-Screen {}
  function Show-WorkPage {}
  Assert-Equal "fait" (Invoke-UiWork "Titre" "texte" { $script:UiKeys.Enqueue("k"); "fait" }) "ecran d'attente : resultat rendu"
  Assert-Equal 0 $script:UiKeys.Count "ecran d'attente : touches tapees pendant l'attente oubliees"
  Assert-Null $script:UiPulse "ecran d'attente : animation arretee a la fin"
} finally {
  foreach ($n in $workKept.Keys) { Set-Item -Path ("function:" + $n) -Value $workKept[$n] }
  $script:WorkPage = $null
}

$rows = Get-ListRows @("un", "deux") 1 @($true, $false)
Assert-Equal ("    " + [char]0x25A0 + "  un") (Get-RowText $rows[0]) "case cochee"
Assert-True ((Get-RowText $rows[1]).StartsWith("  " + $script:Mark + " " + [char]0x25A1 + "  deux")) "repere sur la case choisie"
$rows = Get-ListRows @("a", "b") 0
Assert-Equal "    2  b" (Get-RowText $rows[1]) "liste numerotee"
$side = [string][char]0x2502
$p = Get-PageRows "Titre" $rows @("Echap", "annuler") "sous-titre"
$pt = @(foreach ($r in $p) { Get-RowText $r })
Assert-Equal 11 $p.Count "page : cadre, titre, sous-titre, filets, lignes et pied"
Assert-True ($pt[0].StartsWith([string][char]0x256D)) "page : bord du haut"
Assert-True ($pt[1].StartsWith($side + "  Titre ")) "titre de page dans le cadre"
Assert-True ($pt[9].StartsWith($side + "  Echap annuler ")) "pied de page dans le cadre"
Assert-True ($pt[10].StartsWith([string][char]0x2570)) "page : bord du bas"
Assert-Equal "" (@($pt | Where-Object { $_.Length -ne $script:UiClip }) -join "|") "page : cadre a la largeur de l'ecran"
$p = Get-PageRows "Titre" $rows
Assert-True ((Get-RowText $p[$p.Count - 2]) -notmatch $script:Rule) "attente sans pied : pas de filet contre le bord du bas"
$keptClip = $script:UiClip
$script:UiClip = 30
try {
  $p = Get-PageRows "Titre" $rows
  Assert-Equal "  Titre" (Get-RowText $p[1]) "ecran trop etroit : page sans cadre"
} finally { $script:UiClip = $keptClip }

foreach ($f in Get-ChildItem -LiteralPath $bin -Filter "*.ps1" -Recurse) {
  $errs = $null
  $null = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errs)
  Assert-Equal 0 @($errs).Count ("syntaxe de " + $f.Name)
}
