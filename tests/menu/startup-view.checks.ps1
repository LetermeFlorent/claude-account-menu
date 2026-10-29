. (Join-Path $bin "claude-menu-startup.ps1")

function Get-ViewText {
  param($Row)
  $t = ""
  foreach ($s in $Row) { $t += $s[0] }
  return $t
}

function New-ViewEntry {
  param([string]$Label)
  $u = [PSCustomObject]@{ Label = $Label; Email = ($Label + "@x.fr"); Plan = "Pro"; Error = "panne"; Acc = $null }
  return @{ U = $u; Pending = $false; Seen = $true; In = $null; View = @{ Badge = ""; Note = "" }; Timer = $null }
}

function New-ViewStartup {
  $su = New-Startup @("clm", "claude", "drive")
  $s = $su.Steps
  $s[0].State = "done"; $s[0].Kind = "ok"; $s[0].Text = "a jour"; $s[0].Pct = 100; $s[0].Bar = New-Tween 100 100 0 0
  $s[1].State = "run"; $s[1].Pct = 45; $s[1].Text = "telechargement 2.1.300  45 / 100 Mo"; $s[1].Bar = New-Tween 45 45 0 0
  return $su
}

function Get-StartupViewRows {
  param($Su, $L, [double]$Now = 0)
  $rows = New-Object 'System.Collections.Generic.List[object]'
  $fades = New-Object 'System.Collections.Generic.List[double]'
  Add-StartupRows $rows $fades $Su $L $Now
  return @{ Rows = $rows; Fades = $fades; Texts = @(foreach ($r in $rows) { Get-ViewText $r }) }
}

$green = $script:Levels["7d"][0] -join " "
$su = New-ViewStartup
Assert-Equal 4 (Get-StartupRowCount $su) "lancement : une rangee par etape et une vide"
Assert-Equal 0 (Get-StartupRowCount $null) "sans lancement : aucune rangee"
$su.Hidden = $true
Assert-Equal 0 (Get-StartupRowCount $su) "lancement fini : aucune rangee"
$su.Hidden = $false

$L = Get-MenuLayout 120 40 3 4
$v = Get-StartupViewRows $su $L
Assert-Equal 4 $v.Rows.Count "barres puis rangee vide"
Assert-Equal ("  clm          " + ($script:BarFull * 19) + $script:BarHalf + "  a jour") $v.Texts[0] "clm a jour : barre pleine"
Assert-Equal $green ($v.Rows[0][1][1] -join " ") "barre pleine en vert, comme la barre 7d"
Assert-Equal ("  Claude Code  " + ($script:BarFull * 8) + $script:BarHalf + ($script:BarEmpty * 11) + "   45%  telechargement 2.1.300  45 / 100 Mo") $v.Texts[1] "Claude Code : barre, pourcentage et detail"
Assert-Equal ("  Drive        " + ($script:BarEmpty * 20) + "  " + (Get-ClmText "menu.startup.after" @("clm"))) $v.Texts[2] "Drive en attente : barre vide"
Assert-Equal (($script:Ink.Cell -join " ") + " " + ($script:Ink.Dim -join " ")) (($v.Rows[2][1][1] -join " ") + " " + ($v.Rows[2][2][1] -join " ")) "attente : cases vides et texte attenue"
Assert-Equal "" $v.Texts[3] "rangee vide avant les comptes"

$su.Steps[1].Pct = -1
$su.Steps[1].Text = "recherche de mise a jour"
$v = Get-StartupViewRows $su $L 600
Assert-Equal ("  Claude Code  " + ($script:BarEmpty * 20) + "  recherche de mise a jour") $v.Texts[1] "sans pourcentage : barre qui scintille, pas de chiffre"
Assert-True (Test-StartupAnimating $su 600) "barre qui scintille : animee"

$su.Steps[1].State = "done"; $su.Steps[1].Kind = "updated"; $su.Steps[1].Text = "mis a jour, 2.1.292 -> 2.1.300"; $su.Steps[1].Pct = 100
$su.Steps[1].Bar = New-Tween 45 100 350 1000
$su.Steps[2].State = "done"; $su.Steps[2].Kind = "failed"; $su.Steps[2].Text = "erreur"; $su.Steps[2].Pct = 100; $su.Steps[2].Bar = New-Tween 100 100 0 0
Assert-True (Test-StartupAnimating $su 1100) "barre qui se remplit : animee"
Assert-True (-not (Test-StartupAnimating $su 1400)) "barres immobiles : rien a animer"
$v = Get-StartupViewRows $su $L 1400
Assert-Equal $green ($v.Rows[1][$v.Rows[1].Count - 1][1] -join " ") "mise a jour faite : texte en vert"
Assert-Equal ($script:Ink.Alert -join " ") ($v.Rows[2][1][1] -join " ") "echec : barre rouge"
Assert-Equal ($script:Ink.Alert -join " ") ($v.Rows[2][$v.Rows[2].Count - 1][1] -join " ") "echec : texte rouge"

$v = Get-StartupViewRows $su $L 9000
Assert-Equal 1 $v.Fades[2] "echec : ligne gardee en pleine intensite"

$su = New-ViewStartup
$su.Steps[0].Fade = @{ From = 1; To = 0; Ms = 300; Start = 1000 }
$v = Get-StartupViewRows $su $L 1150
Assert-True ($v.Fades[0] -eq 0.125 -and $v.Fades[1] -eq 1 -and $v.Fades[2] -eq 1) "ligne a jour : fondu de la ligne seule"
Assert-True (Test-StartupAnimating $su 1150) "ligne a jour : fondu anime"
$su.Steps[0].Gone = $true
$v = Get-StartupViewRows $su $L 1400
Assert-Equal 3 (Get-StartupRowCount $su) "ligne partie : une rangee de moins"
Assert-True ($v.Texts[0].StartsWith("  Claude Code ") -and $v.Texts[2] -eq "") "ligne partie : les suivantes remontent"
$su.Steps[1].Gone = $true; $su.Steps[2].Gone = $true
Assert-Equal 0 (Get-StartupRowCount $su) "toutes les lignes parties : aucune rangee"

$su = New-ViewStartup
$narrow = Get-MenuLayout 60 40 3 4
$v = Get-StartupViewRows $su $narrow
Assert-Equal ($narrow.W - 2) $v.Texts[1].Length "fenetre etroite : detail raccourci a la largeur"
Assert-True ($v.Texts[1].EndsWith("telecharg...")) "fenetre etroite : detail coupe"

$st = @{ Entries = @((New-ViewEntry "a"), (New-ViewEntry "b"), (New-ViewEntry "c")); Sel = 0; SelTween = (New-Tween 0 0 0 0); Top = 0; Msg = @("  pret", $script:Ink.Dim); Moved = $false }
$script:Startup = $su
try {
  $su.Steps[0].State = "run"
  $f = Get-MenuRows $st (Get-MenuLayout 120 40 3 (Get-StartupRowCount $su)) 0
  Assert-Equal "8 0 0" ("" + $st.Hit.Start + " " + $st.Hit.Top + " " + $st.Hit.Last) "verification de clm : aucun compte affiche"
  Assert-Equal -1 (Get-EntryAt $st 8) "verification de clm : clic sans compte"
  $su.Steps[0].State = "done"
  $f = Get-MenuRows $st (Get-MenuLayout 120 40 3 (Get-StartupRowCount $su)) 0
  $texts = @(foreach ($r in $f.Rows) { Get-ViewText $r })
  Assert-True ($texts[4].StartsWith("  clm  ")) "menu : barres sous le titre"
  Assert-Equal 8 $st.Hit.Start "menu : comptes decales sous les barres"
  Assert-True ($texts[8].StartsWith("  " + $script:Mark + " 1  a")) "menu : premier compte sous les barres"
  Assert-Equal 0 (Get-EntryAt $st 8) "souris : clic sur le premier compte"
  Assert-Equal -1 (Get-EntryAt $st 5) "souris : clic sur une barre ignore"
  $boxed = @(foreach ($r in (Get-FramedRows $f.Rows $f.Fades 105)) { Get-ViewText $r })
  Assert-True ($boxed[8].StartsWith([string][char]0x2502 + "  " + $script:Mark + " 1  a")) "cadre : premier compte sur la meme ligne, souris juste"
  Assert-True ($boxed[$boxed.Count - 2].StartsWith([string][char]0x2502 + "  pret")) "cadre : message dans le cadre"
  $f = Get-MenuRows $st (Get-MenuLayout 30 12 3 (Get-StartupRowCount $su)) 0
  $texts = @(foreach ($r in $f.Rows) { Get-ViewText $r })
  Assert-Equal ("  clm  a jour|  Claude Code  45%  telechargement 2.1.300  45 / 100 Mo|  Drive  " + (Get-ClmText "menu.startup.after" @("clm"))) ($texts[1..3] -join "|") "vue simple : etapes en texte"
  Assert-Equal 4 $st.Hit.Start "vue simple : comptes sous les etapes"
  $su.Hidden = $true
  $f = Get-MenuRows $st (Get-MenuLayout 120 40 3 (Get-StartupRowCount $su)) 0
  Assert-Equal 4 $st.Hit.Start "lancement fini : comptes remontes"
} finally { $script:Startup = $null }
