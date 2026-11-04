. (Join-Path $bin "core/claude-lang.ps1")

$langHome = Join-Path $script:Sandbox "lang-home"
New-Item -ItemType Directory -Path $langHome -Force | Out-Null
$langFaked = @("Read-UiCulture", "Read-MacLanguages")
$langKept = @{}
foreach ($n in $langFaked) { $langKept[$n] = (Get-Item ("function:" + $n)).ScriptBlock }
$script:LangUi = ""
$script:LangMac = ""
function Read-UiCulture { return $script:LangUi }
function Read-MacLanguages { return $script:LangMac }

function New-LangVars {
  param([hashtable]$Extra = @{})
  $v = @{ USERPROFILE = $langHome; HOME = $langHome }
  foreach ($k in $Extra.Keys) { $v[$k] = $Extra[$k] }
  return $v
}

try {
  Assert-Equal "fr" (ConvertTo-LangCode "fr_FR.UTF-8") "langue : fr_FR.UTF-8 donne fr"
  Assert-Equal "en" (ConvertTo-LangCode "de-DE") "langue : autre langue donne en"
  Assert-Equal "" (ConvertTo-LangCode "C.UTF-8") "langue : C ignore"
  Assert-Equal "" (ConvertTo-LangCode "POSIX") "langue : POSIX ignore"
  Assert-Equal "fr-FR" (ConvertFrom-MacLanguages "(`n    `"fr-FR`",`n    `"en-US`"`n)") "langue : premiere langue macOS"
  Assert-Equal "" (ConvertFrom-MacLanguages "") "langue : macOS sans liste"

  $script:LangUi = "fr-FR"
  Assert-Equal "fr" (Get-SystemLang "Windows" (New-LangVars)) "langue Windows : culture de l'interface"
  $script:LangUi = ""
  Assert-Equal "fr" (Get-SystemLang "Windows" (New-LangVars @{ LANG = "fr_CA.UTF-8" })) "langue Windows : LANG quand la culture est vide"
  $script:LangUi = "en-US"
  Assert-Equal "en" (Get-SystemLang "Windows" (New-LangVars @{ LANG = "fr_FR.UTF-8" })) "langue Windows : culture avant LANG"

  $script:LangMac = "(`n    `"fr-FR`"`n)"
  Assert-Equal "fr" (Get-SystemLang "MacOS" (New-LangVars @{ LANG = "en_US.UTF-8" })) "langue macOS : AppleLanguages avant LANG"
  $script:LangMac = ""
  Assert-Equal "en" (Get-SystemLang "MacOS" (New-LangVars @{ LANG = "en_US.UTF-8" })) "langue macOS : LANG sans AppleLanguages"

  $linux = New-LangVars @{ LC_ALL = "fr_FR.UTF-8"; LC_MESSAGES = "en_US.UTF-8"; LANG = "en_US.UTF-8" }
  Assert-Equal "fr" (Get-SystemLang "Linux" $linux) "langue Linux : LC_ALL d'abord"
  $linux = New-LangVars @{ LC_ALL = ""; LC_MESSAGES = "fr_FR.UTF-8"; LANG = "en_US.UTF-8" }
  Assert-Equal "fr" (Get-SystemLang "Linux" $linux) "langue Linux : LC_MESSAGES avant LANG"
  $linux = New-LangVars @{ LC_ALL = "C"; LANG = "fr_BE.UTF-8" }
  Assert-Equal "fr" (Get-SystemLang "Linux" $linux) "langue Linux : C passe la main a LANG"
  Assert-Equal "" (Get-SystemLang "Linux" (New-LangVars)) "langue Linux : rien de detecte"

  function Read-UiCulture { throw "culture illisible" }
  function Read-MacLanguages { throw "defaults absent" }
  Assert-Equal "" (Get-SystemLang "Windows" (New-LangVars)) "langue Windows : lecture en echec sans erreur"
  Assert-Equal "en" (Get-SystemLang "MacOS" (New-LangVars @{ LANG = "en_GB.UTF-8" })) "langue macOS : defaults absent sans erreur"
  Assert-Equal "en" (Get-ClmLang "Linux" (New-LangVars)) "langue : anglais quand rien n'est detecte"
  Assert-Equal "fr" (Get-ClmLang "Linux" (New-LangVars @{ CLM_LANG = "fr"; LANG = "en_US.UTF-8" })) "langue : CLM_LANG avant le systeme"

  $null = Set-DisplayValues @{ lang = "en" } (New-LangVars)
  Assert-Equal "en" (Get-ClmLang "Linux" (New-LangVars @{ CLM_LANG = "fr" })) "langue : choix enregistre avant CLM_LANG"
  Assert-Equal "en" (Read-DisplayConfig (New-LangVars)).lang "langue : choix garde dans les reglages"
  $null = Set-DisplayValues @{ lang = "auto" } (New-LangVars)
  Assert-Equal "fr" (Get-ClmLang "Linux" (New-LangVars @{ LANG = "fr_FR.UTF-8" })) "langue : auto rend la main au systeme"
  Assert-Throws { Set-DisplayValues @{ lang = "de" } (New-LangVars) } ((Get-ClmText "ui.display.badLang" "de").Split(":")[0]) "langue : choix inconnu refuse"
  $langPath = (Get-Item "function:Get-DisplayPath").ScriptBlock
  $script:LangPathCalls = 0
  function Get-DisplayPath { param($Vars = $null) $script:LangPathCalls++; & $langPath $Vars }
  $script:LangPrefCache = $null
  $null = Get-PreferredLang
  $script:LangPathCalls = 0
  foreach ($i in 1..20) { $null = Get-PreferredLang }
  Assert-Equal 0 $script:LangPathCalls "langue : choix enregistre regarde une fois pour vingt textes de suite"
  $langApp = $env:LOCALAPPDATA
  $env:LOCALAPPDATA = $langHome
  $null = Get-PreferredLang
  $env:LOCALAPPDATA = $langApp
  Set-Item function:Get-DisplayPath $langPath
  Assert-True ($script:LangPathCalls -gt 0) "langue : autre dossier d'etat, choix regarde de nouveau"
  $langPref = (Get-Item "function:Get-PreferredLang").ScriptBlock
  $langForced = $env:CLM_LANG
  $langFile = Get-DisplayPath
  $langHadFile = Test-Path -LiteralPath $langFile
  try {
    $script:LangPrefCalls = 0
    Set-Item function:Get-PreferredLang { $script:LangPrefCalls++; & $langPref @args }
    $null = Get-ClmText "ui.footer.quit"
    $script:LangPrefCalls = 0
    foreach ($i in 1..20) { $null = Get-ClmText "ui.footer.quit" }
    Assert-Equal 0 $script:LangPrefCalls "langue : vingt textes de suite sans chercher la langue"
    Set-Item function:Get-PreferredLang $langPref
    $env:CLM_LANG = "fr"
    Assert-Equal "quitter" (Get-ClmText "ui.footer.quit") "langue : CLM_LANG en francais, texte aussitot en francais"
    $env:CLM_LANG = "en"
    Assert-Equal "quit" (Get-ClmText "ui.footer.quit") "langue : CLM_LANG en anglais, texte aussitot en anglais"
    $null = Set-DisplayValues @{ lang = "fr" }
    Assert-Equal "quitter" (Get-ClmText "ui.footer.quit") "langue : choix enregistre, texte aussitot dans la langue choisie"
  } finally {
    Set-Item function:Get-PreferredLang $langPref
    $env:CLM_LANG = $langForced
    if (-not $langHadFile) { Remove-Item -LiteralPath $langFile -ErrorAction SilentlyContinue }
    else { $null = Set-DisplayValues @{ lang = "auto" } }
    $script:LangPrefCache = $null
  }
} finally {
  foreach ($n in $langFaked) { Set-Item ("function:" + $n) $langKept[$n] }
  Remove-Item -LiteralPath (Get-DisplayPath (New-LangVars)) -ErrorAction SilentlyContinue
}
