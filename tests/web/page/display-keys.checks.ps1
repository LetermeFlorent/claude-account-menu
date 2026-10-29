. (Join-Path $bin "claude-display.ps1")

$dkHome = Join-Path $script:Sandbox "display-keys-home"
$dkVars = @{ USERPROFILE = $dkHome; HOME = $dkHome }
$dkPath = Get-DisplayPath $dkVars

try {
  $d = Read-DisplayConfig $dkVars
  Assert-Equal "auto auto auto system" ($d.palette + " " + $d.anim + " " + $d.lang + " " + $d.webTheme) "affichage : valeurs par defaut"

  $null = New-Item -ItemType Directory -Path (Split-Path -Parent $dkPath) -Force
  [IO.File]::WriteAllText($dkPath, '{"palette":"dark","usagePoll":45,"future":{"a":1}}')
  $d = Set-DisplayValues ([ordered]@{ lang = "fr"; webTheme = "dark" }) $dkVars
  Assert-Equal "dark fr dark" ($d.palette + " " + $d.lang + " " + $d.webTheme) "affichage : langue et theme de la page enregistres"
  $raw = ConvertFrom-JsonText ([IO.File]::ReadAllText($dkPath))
  Assert-Equal "45 1" ("" + $raw["usagePoll"] + " " + $raw["future"]["a"]) "affichage : cles inconnues gardees"

  $d = Save-DisplayConfig "light" "off" $dkVars
  $raw = ConvertFrom-JsonText ([IO.File]::ReadAllText($dkPath))
  Assert-Equal "light off fr dark 45 1" ($d.palette + " " + $d.anim + " " + $d.lang + " " + $d.webTheme + " " + $raw["usagePoll"] + " " + $raw["future"]["a"]) "affichage : terminal enregistre sans perdre le reste"
  $null = Set-DisplayPalette "dark" $dkVars
  $null = Set-DisplayAnim "on" $dkVars
  $raw = ConvertFrom-JsonText ([IO.File]::ReadAllText($dkPath))
  Assert-Equal "dark on 45" ("" + $raw["palette"] + " " + $raw["anim"] + " " + $raw["usagePoll"]) "affichage : reglage seul, cles inconnues gardees"

  Assert-Throws { Set-DisplayValues @{ webTheme = "violet" } $dkVars } "theme de la page inconnu" "affichage : theme de la page inconnu refuse"
  Assert-Throws { Set-DisplayValues @{ usagePoll = 20 } $dkVars } "reglage d'affichage inconnu" "affichage : cle d'un autre module refusee ici"
  Assert-Equal "45" (ConvertFrom-JsonText ([IO.File]::ReadAllText($dkPath)))["usagePoll"] "affichage : refus sans ecriture"

  [IO.File]::WriteAllText($dkPath, '{"lang":"de","webTheme":"rose"}')
  $d = Read-DisplayConfig $dkVars
  Assert-Equal "auto system" ($d.lang + " " + $d.webTheme) "affichage : valeurs illisibles, defaut"
  [IO.File]::WriteAllText($dkPath, "pas du json")
  $d = Set-DisplayValues @{ lang = "en" } $dkVars
  Assert-Equal "en auto" ($d.lang + " " + $d.palette) "affichage : fichier illisible remplace"
} finally {
  Remove-Item -LiteralPath $dkHome -Recurse -Force -ErrorAction SilentlyContinue
}
