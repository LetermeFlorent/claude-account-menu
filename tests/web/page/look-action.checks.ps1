. (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) "actions") "actions-fakes.ps1")

$laFaked = @("Read-UsagePollSeconds", "Set-DisplayUsagePoll", "Get-SystemTheme", "Read-WindowsAccent")
$laKept = @{}
foreach ($n in $laFaked) {
  $item = Get-Item ("function:" + $n) -ErrorAction SilentlyContinue
  $laKept[$n] = $null
  if ($item) { $laKept[$n] = $item.ScriptBlock }
}
$script:LaPoll = 30
$script:LaSet = @()
$script:LaTheme = ""
$script:LaAccent = ""
function Read-UsagePollSeconds { param($Vars = $null) return $script:LaPoll }
function Set-DisplayUsagePoll { param($Seconds, $Vars = $null) $script:LaSet += $Seconds; $script:LaPoll = $Seconds; return $Seconds }
function Get-SystemTheme { param([string]$Os = "", $Vars = $null) return $script:LaTheme }
function Read-WindowsAccent { param([string]$Os = "") return $script:LaAccent }

try {
  $script:Startup = $null
  Reset-MenuState @("", $script:Ink.Dim) 0
  Clear-WebSystemLook
  Assert-Equal "light" (ConvertTo-WebTheme "system" "") "page : rien de detecte, theme clair"
  Assert-Equal "dark" (ConvertTo-WebTheme "system" "dark") "page : theme sombre du systeme suivi"
  Assert-Equal "light" (ConvertTo-WebTheme "light" "dark") "page : choix clair avant le systeme"
  $lk = Get-WebLook
  Assert-Equal "system light  auto" ($lk.themePref + " " + $lk.theme + " " + $lk.themeFound + " " + $lk.langPref) "page : apparence par defaut"
  Assert-Null $lk.accent.light "page : sans accent Windows, accent de la palette"

  $r = Invoke-ActTest @{ do = "look"; theme = "dark" }
  Assert-Equal "True dark dark" ("" + $r.Ok + " " + $r.Data.themePref + " " + $r.Data.theme) "page : choix du theme sombre"
  Assert-Equal "dark" (Read-DisplayConfig).webTheme "page : choix du theme enregistre"
  $r = Invoke-ActTest @{ do = "look"; lang = "fr" }
  Assert-Equal "True fr fr" ("" + $r.Ok + " " + $r.Data.langPref + " " + $r.Data.lang) "page : choix de la langue"
  Assert-Equal "fr dark" ((Read-DisplayConfig).lang + " " + (Read-DisplayConfig).webTheme) "page : langue enregistree, theme garde"
  Assert-Equal "fr" (Get-ClmLang) "page : langue choisie suivie par clm"
  $r = Invoke-ActTest @{ do = "look"; lang = "de" }
  Assert-Equal ("False " + (Get-ClmText "server.unknownLang" @("de"))) ("" + $r.Ok + " " + $r.Msg) "page : langue inconnue refusee"
  $r = Invoke-ActTest @{ do = "look"; theme = "violet" }
  Assert-Equal ("False " + (Get-ClmText "server.unknownTheme" @("violet"))) ("" + $r.Ok + " " + $r.Msg) "page : theme inconnu refuse"
  Assert-Equal "fr dark" ((Read-DisplayConfig).lang + " " + (Read-DisplayConfig).webTheme) "page : choix refuse, rien d'ecrit"
  $r = Invoke-ActTest @{ do = "look"; lang = "auto"; theme = "system" }
  Assert-Equal "auto system light" ($r.Data.langPref + " " + $r.Data.themePref + " " + $r.Data.theme) "page : retour au systeme"

  $script:LaTheme = "dark"
  $script:LaAccent = "#0078d7"
  $r = Invoke-ActTest @{ do = "look" }
  Assert-Equal "dark dark" ($r.Data.themeFound + " " + $r.Data.theme) "page : theme du systeme relu a la demande"
  Assert-Equal "#0078d7 #000000" ($r.Data.accent.light.fill + " " + $r.Data.accent.light.ink) "page : accent Windows garde s'il passe le niveau AA"
  Assert-Null $r.Data.accent.dark "page : accent Windows trop sombre en theme sombre, accent de la palette"
  $script:Startup = @{ Steps = @(@{ Name = "claude"; State = "run" }) }
  Assert-True (Invoke-ActTest @{ do = "look" }).Ok "page : apparence lue pendant le demarrage"
  Assert-True (Invoke-ActTest @{ do = "usagepoll" }).Ok "page : delai des quotas lu pendant le demarrage"
  $script:Startup = $null

  $r = Invoke-ActTest @{ do = "usagepoll" }
  Assert-Equal "True 30 15 600" ("" + $r.Ok + " " + $r.Data.seconds + " " + $r.Data.min + " " + $r.Data.max) "quotas : delai lu"
  Assert-Equal 0 $script:LaSet.Count "quotas : lecture sans ecriture"
  $r = Invoke-ActTest @{ do = "usagepoll"; seconds = "120" }
  Assert-Equal ("True 120 " + (Get-ClmText "server.usagePollSaved" @(120))) ("" + $r.Ok + " " + $r.Data.seconds + " " + $r.Msg) "quotas : delai enregistre"
  Assert-Equal "120" ($script:LaSet -join " ") "quotas : ecriture par Set-DisplayUsagePoll"
  foreach ($bad in @("14", "601", "abc", "-5", "1e3", "99999")) {
    $r = Invoke-ActTest @{ do = "usagepoll"; seconds = $bad }
    Assert-Equal ("False " + (Get-ClmText "server.badUsagePoll" @($bad, 15, 600))) ("" + $r.Ok + " " + $r.Msg) ("quotas : delai refuse [" + $bad + "]")
  }
  Assert-Equal "120" ($script:LaSet -join " ") "quotas : rien d'ecrit apres un refus"
} finally {
  foreach ($n in $laFaked) {
    if ($null -eq $laKept[$n]) { Remove-Item ("function:" + $n) -ErrorAction SilentlyContinue } else { Set-Item ("function:" + $n) $laKept[$n] }
  }
  Clear-WebSystemLook
  Restore-ActFakes
}
