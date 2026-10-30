. (Join-Path $bin "menu/startup/claude-menu-startup.ps1")
. (Join-Path $bin "ui/display/claude-boot-bar.ps1")

$wideLabel = ([string][char]0x65E5) + [char]0x672C + [char]0x8A9E
$accentLabel = "Synchronis" + [char]0xE9 + [char]0xE8
$keptLang = $env:CLM_LANG

Assert-Equal 13 (Get-DisplayWidth (Get-PaddedLabel $wideLabel 13)) "libelle large : rempli a treize cellules"
Assert-Equal 10 (Get-PaddedLabel $wideLabel 13).Length "libelle large : moins de caracteres que de cellules"
Assert-Equal 13 (Get-DisplayWidth (Get-PaddedLabel $accentLabel 13)) "libelle accentue : rempli a treize cellules"
Assert-Equal 13 (Get-PaddedLabel "clm" 13).Length "libelle ASCII : rempli comme avant"
Assert-Equal "abcdefghijklmnop" (Get-PaddedLabel "abcdefghijklmnop" 13) "libelle plus long que la colonne : intact"

$su = New-Startup @("clm", "claude")
$su.Steps[0].Label = $wideLabel
$su.Steps[1].Label = $accentLabel
$su.Steps[0].Pct = 100
$su.Steps[1].Pct = 100
$L = @{ W = 80; Cells = 20 }
foreach ($i in 0, 1) {
  $row = Get-StartupRow $su.Steps[$i] $L 0
  Assert-Equal 15 (Get-DisplayWidth $row[0][0]) ("rangee de demarrage " + $i + " : colonne du libelle a quinze cellules")
}

try {
  foreach ($code in "fr", "en") {
    $env:CLM_LANG = $code
    Assert-Equal 13 (Get-DisplayWidth (Get-BootBarLabel)) ("barre de demarrage : libelle sur treize cellules en " + $code)
    Assert-Equal 13 (Get-DisplayWidth (Get-PaddedLabel (Get-StartupLabel "claude") 13)) ("etape de demarrage : libelle sur treize cellules en " + $code)
  }
} finally {
  if ($null -eq $keptLang) { Remove-Item Env:CLM_LANG -ErrorAction SilentlyContinue } else { $env:CLM_LANG = $keptLang }
}
