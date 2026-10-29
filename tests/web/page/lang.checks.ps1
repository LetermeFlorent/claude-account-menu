. (Join-Path $bin "claude-lang.ps1")

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
  Assert-Throws { Set-DisplayValues @{ lang = "de" } (New-LangVars) } "langue inconnue" "langue : choix inconnu refuse"
} finally {
  foreach ($n in $langFaked) { Set-Item ("function:" + $n) $langKept[$n] }
  Remove-Item -LiteralPath (Get-DisplayPath (New-LangVars)) -ErrorAction SilentlyContinue
}
