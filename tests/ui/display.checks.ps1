$displayHome = Join-Path $script:Sandbox "display-home"
New-Item -ItemType Directory -Path $displayHome -Force | Out-Null
$displayVars = @{ USERPROFILE = $displayHome; HOME = $displayHome }

$d = Read-DisplayConfig $displayVars
Assert-Equal "auto auto" ($d.palette + " " + $d.anim) "affichage : sans fichier, tout suit le systeme"
$null = Set-DisplayPalette "clair" $displayVars
$d = Read-DisplayConfig $displayVars
Assert-Equal "light auto" ($d.palette + " " + $d.anim) "affichage : couleurs claires gardees, clair accepte"
$null = Set-DisplayAnim "off" $displayVars
$d = Read-DisplayConfig $displayVars
Assert-Equal "light off" ($d.palette + " " + $d.anim) "affichage : animations coupees sans toucher aux couleurs"
Assert-Equal "light" (Get-ThemeName $script:OsName $displayVars) "affichage : couleurs du fichier avant le systeme"
Assert-True (New-ThemeWatch $script:OsName $displayVars 0 { "dark" }).Fixed "affichage : couleurs du fichier, pas de suivi du systeme"
Assert-True (-not (Get-MotionEnabled $script:OsName $displayVars)) "affichage : animations coupees par le fichier"
$displayVars["CLM_ANIM"] = "1"
Assert-True (Get-MotionEnabled $script:OsName $displayVars) "affichage : CLM_ANIM passe avant le fichier"
$displayVars["STATUSLINE_BG"] = "dark"
Assert-Equal "dark" (Get-ThemeName $script:OsName $displayVars) "affichage : STATUSLINE_BG passe avant le fichier"
$displayVars.Remove("STATUSLINE_BG")
$displayVars.Remove("CLM_ANIM")

$displayErr = ""
try { $null = Set-DisplayPalette "rouge" $displayVars } catch { $displayErr = $_.Exception.Message }
Assert-True ($displayErr -like ((Get-ClmText "ui.display.badPalette" "rouge").Split(":")[0] + "*")) "affichage : couleur inconnue refusee"
try { $null = Set-DisplayAnim "parfois" $displayVars } catch { $displayErr = $_.Exception.Message }
Assert-True ($displayErr -like ((Get-ClmText "ui.display.badAnim" "parfois").Split(":")[0] + "*")) "affichage : animation inconnue refusee"
Assert-Equal "light off" ((Read-DisplayConfig $displayVars).palette + " " + (Read-DisplayConfig $displayVars).anim) "affichage : refus sans rien changer"

[IO.File]::WriteAllText((Get-DisplayPath $displayVars), '{"palette":"Dark","anim":"rouge"}')
$d = Read-DisplayConfig $displayVars
Assert-Equal "dark auto" ($d.palette + " " + $d.anim) "affichage : casse ignoree, valeur inconnue remise a auto"
foreach ($bad in @("pas du json", "[1,2]", '"dark"', "")) {
  [IO.File]::WriteAllText((Get-DisplayPath $displayVars), $bad)
  $d = Read-DisplayConfig $displayVars
  Assert-Equal "auto auto" ($d.palette + " " + $d.anim) ("affichage : fichier illisible [" + $bad + "]")
}
