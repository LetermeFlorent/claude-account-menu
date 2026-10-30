$langFiles = @("claude-menu-screen.ps1", "claude-menu-startup.ps1", "claude-menu-startup-steps.ps1", "claude-menu-startup-view.ps1", "claude-menu-progress.ps1", "claude-boot-bar.ps1")
$langTables = @{}
foreach ($code in "en", "fr") {
  $langTables[$code] = ConvertFrom-JsonText ([IO.File]::ReadAllText((Join-Path $bin ("lang\" + $code + ".json")), [Text.Encoding]::UTF8))
}
$langUsed = @()
foreach ($f in $langFiles) {
  $langUsed += @([regex]::Matches([IO.File]::ReadAllText((Join-Path $bin $f)), '"(menu\.(?:screen|startup|progress|boot)\.[a-z_.]+)"') | ForEach-Object { $_.Groups[1].Value })
}
$langUsed = @($langUsed | Sort-Object -Unique)
Assert-True ($langUsed.Count -ge 17) "textes de l'ecran et du demarrage : cles trouvees dans les fichiers"
foreach ($k in $langUsed) {
  Assert-True ($langTables["en"].Contains($k) -and $langTables["fr"].Contains($k)) ("cle " + $k + " : presente en anglais et en francais")
}

$accentless = '\b(apres|laissee|preparation|demarrage|affiches|arret|demande|verification|mise a jour|a jour|lance|remplace|maj)\b'
foreach ($k in @($langTables["fr"].Keys | Where-Object { $_ -match '^menu\.(screen|startup|progress|boot)\.' })) {
  Assert-True ($langTables["fr"][$k] -notmatch $accentless) ("cle " + $k + " : francais avec ses accents")
}

Assert-Equal ([string][char]0xE0 + " jour") $langTables["fr"]["menu.startup.up_to_date"] "francais : a jour avec son accent"
Assert-Equal ("pr" + [char]0xE9 + "paration") $langTables["fr"]["menu.startup.preparing"] "francais : preparation avec son accent"
Assert-Equal ("d" + [char]0xE9 + "marrage") $langTables["fr"]["menu.boot.starting"] "francais : demarrage avec son accent"
Assert-Equal ("laiss" + [char]0xE9 + "e " + [char]0xE0 + " un autre clm") $langTables["fr"]["menu.startup.left_to_other_clm"] "francais : laissee a un autre clm avec ses accents"

$keptLang = $env:CLM_LANG
try {
  $env:CLM_LANG = "fr"
  $frFirst = Get-StartupLabel "drive"
  $frText = Get-ClmText "menu.startup.up_to_date"
  $env:CLM_LANG = "en"
  Assert-Equal "up to date" (Get-ClmText "menu.startup.up_to_date") "langue changee apres le chargement : texte relu"
  Assert-True ((Get-ClmText "menu.startup.up_to_date") -ne $frText) "langue changee apres le chargement : plus le texte francais"
  Assert-Equal "Drive" $frFirst "libelle Drive identique dans les deux langues"
} finally {
  if ($null -eq $keptLang) { Remove-Item Env:CLM_LANG -ErrorAction SilentlyContinue } else { $env:CLM_LANG = $keptLang }
}
