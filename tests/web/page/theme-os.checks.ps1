. (Join-Path $bin "claude-theme.ps1")

$toHome = Join-Path $script:Sandbox "theme-os-home"
$toVars = @{ USERPROFILE = $toHome; HOME = $toHome; XDG_CONFIG_HOME = (Join-Path $toHome "cfg") }
$toFaked = @("Read-WindowsLightTheme", "Read-MacAppearance", "Read-GnomeSetting")
$toKept = @{}
foreach ($n in $toFaked) { $toKept[$n] = (Get-Item ("function:" + $n)).ScriptBlock }
$script:ToWin = $null
$script:ToMac = $null
$script:ToGnome = @{}
function Read-WindowsLightTheme { return $script:ToWin }
function Read-MacAppearance { return $script:ToMac }
function Read-GnomeSetting { param([string]$Name) return [string]$script:ToGnome[$Name] }

try {
  $script:ToWin = 0
  Assert-Equal "dark" (Get-SystemTheme "Windows" $toVars) "theme Windows : AppsUseLightTheme 0 donne sombre"
  $script:ToWin = 1
  Assert-Equal "light" (Get-SystemTheme "Windows" $toVars) "theme Windows : AppsUseLightTheme 1 donne clair"
  $script:ToWin = $null
  Assert-Equal "" (Get-SystemTheme "Windows" $toVars) "theme Windows : valeur absente, rien de detecte"

  $script:ToMac = @{ Code = 0; Out = "Dark" }
  Assert-Equal "dark" (Get-SystemTheme "MacOS" $toVars) "theme macOS : AppleInterfaceStyle Dark"
  $script:ToMac = @{ Code = 1; Out = "" }
  Assert-Equal "light" (Get-SystemTheme "MacOS" $toVars) "theme macOS : cle absente, clair"
  $script:ToMac = $null
  Assert-Equal "" (Get-SystemTheme "MacOS" $toVars) "theme macOS : defaults absent, rien de detecte"

  $script:ToGnome = @{ "color-scheme" = "'prefer-dark'" }
  Assert-Equal "dark" (Get-SystemTheme "Linux" $toVars) "theme Linux : color-scheme prefer-dark"
  $script:ToGnome = @{ "color-scheme" = "'default'"; "gtk-theme" = "'Adwaita-dark'" }
  Assert-Equal "dark" (Get-SystemTheme "Linux" $toVars) "theme Linux : theme GTK en -dark"
  $script:ToGnome = @{ "color-scheme" = "'default'"; "gtk-theme" = "'Adwaita'" }
  Assert-Equal "dark" (Get-SystemTheme "Linux" ($toVars + @{ GTK_THEME = "Yaru-dark" })) "theme Linux : GTK_THEME en -dark"
  Assert-Equal "" (Get-SystemTheme "Linux" $toVars) "theme Linux : aucun indice, rien de detecte"
  $script:ToGnome = @{}
  Assert-Equal "" (Get-SystemTheme "Linux" $toVars) "theme Linux : gsettings absent, rien de detecte"
  $null = New-SandboxFile "theme-os-home/cfg/kdeglobals" "[Colors:Window]`nBackgroundNormal=35,38,41`n"
  Assert-Equal "dark" (Get-SystemTheme "Linux" $toVars) "theme Linux : kdeglobals sombre"

  function Read-WindowsLightTheme { throw "registre illisible" }
  function Read-MacAppearance { throw "defaults absent" }
  function Read-GnomeSetting { throw "gsettings absent" }
  Assert-Equal "" (Get-SystemTheme "Windows" $toVars) "theme Windows : lecture en echec sans erreur"
  Assert-Equal "" (Get-SystemTheme "MacOS" $toVars) "theme macOS : lecture en echec sans erreur"
  Assert-Equal "" (Get-SystemTheme "Linux" $toVars) "theme Linux : lecture en echec sans erreur"
  Assert-Equal "dark" (Get-ThemeName "Windows" $toVars) "theme du terminal : sombre quand rien n'est detecte"
} finally {
  foreach ($n in $toFaked) { Set-Item ("function:" + $n) $toKept[$n] }
}
