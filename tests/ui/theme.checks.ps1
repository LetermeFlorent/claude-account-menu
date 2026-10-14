$themeHome = Join-Path $script:Sandbox "theme-home"
$vars = @{ USERPROFILE = $themeHome; HOME = $themeHome }

Assert-Equal "light" (ConvertTo-ThemeName "CLAIR" -French) "STATUSLINE_BG clair"
Assert-Equal "dark" (ConvertTo-ThemeName " Sombre " -French) "STATUSLINE_BG sombre"
Assert-Null (ConvertTo-ThemeName "clair") "clair refuse hors variable d'environnement"
Assert-Null (ConvertTo-ThemeName "auto") "auto declenche la detection"

$vars["STATUSLINE_BG"] = "Light"
Assert-Equal "light" (Get-ThemeName $script:OsName $vars) "etape 1, variable d'environnement"
$vars["STATUSLINE_BG"] = "rouge"
$system = Get-SystemTheme $script:OsName $vars
if (-not $system) { $system = "dark" }
Assert-Equal $system (Get-ThemeName $script:OsName $vars) "valeur inconnue, theme du systeme"
$vars.Remove("STATUSLINE_BG")
$null = New-SandboxFile "theme-home/.claude/statusline.json" '{"terminal_background":"Light"}'
Assert-Equal $system (Get-ThemeName $script:OsName $vars) "statusline.json ignore"
Assert-True (-not (New-ThemeWatch $script:OsName $vars 0 { "dark" }).Fixed) "statusline.json ne fige pas le theme"
Assert-True (-not (Get-Command Get-BinaryTheme -ErrorAction SilentlyContinue)) "binaire de la barre jamais lance"

Assert-Equal "light" (ConvertFrom-AppsUseLightTheme 1) "Windows AppsUseLightTheme 1"
Assert-Equal "dark" (ConvertFrom-AppsUseLightTheme 0) "Windows AppsUseLightTheme 0"
Assert-Null (ConvertFrom-AppsUseLightTheme $null) "Windows valeur absente"
Assert-Equal "dark" (ConvertFrom-MacAppearance "Dark`n" 0) "macOS sombre"
Assert-Equal "light" (ConvertFrom-MacAppearance "" 1) "macOS, erreur de defaults donc clair"

$kdeDark = New-SandboxFile "kde-dark" "[General]`nBackgroundNormal=255,255,255`n[Colors:Window]`nBackgroundNormal=35,38,41`n"
$kdeLight = New-SandboxFile "kde-light" "[Colors:Window]`nBackgroundNormal = 239, 240, 241`n"
Assert-Equal "dark" (Get-LinuxTheme "'prefer-dark'" "" "") "Linux gsettings sombre"
Assert-Equal "dark" (Get-LinuxTheme "'default'" "Adwaita:dark" "") "Linux GTK_THEME sombre"
Assert-Equal "dark" (Get-LinuxTheme "" "" $kdeDark) "Linux kdeglobals sombre"
Assert-Equal "light" (Get-LinuxTheme "'default'" "Adwaita" $kdeLight) "Linux kdeglobals clair"
Assert-Null (Get-LinuxTheme "'prefer-light'" "" (Join-Path $script:Sandbox "absent")) "Linux sans indice"

$script:probeTheme = "dark"
$probe = { param($O, $V) $script:probeTheme }
$w = New-ThemeWatch $script:OsName $vars 0 $probe
$script:probeTheme = "light"
Assert-Null (Update-ThemeWatch $w $script:OsName $vars 1000) "suivi du theme, pas avant deux secondes"
Assert-Equal "light" (Update-ThemeWatch $w $script:OsName $vars 2500) "suivi du theme, changement vu"
Assert-Null (Update-ThemeWatch $w $script:OsName $vars 5000) "suivi du theme, rien de neuf"
$fixedVars = @{ USERPROFILE = $themeHome; HOME = $themeHome; STATUSLINE_BG = "sombre" }
$w = New-ThemeWatch $script:OsName $fixedVars 0 $probe
$script:probeTheme = "dark"
Assert-Null (Update-ThemeWatch $w $script:OsName $fixedVars 2500) "theme impose, pas de suivi"

$savedInk = $script:Ink
$script:Ink = $script:Palettes["dark"]
Set-UiTheme "light" 0
Assert-True (Update-InkFade 0) "fondu du theme lance"
Assert-Equal "12 12 12" ($script:Ink.Bg -join " ") "fondu du theme au depart"
$null = Update-InkFade 150
Assert-Equal "220 220 220" ($script:Ink.Bg -join " ") "fondu du theme a mi-course"
Assert-True (Update-InkFade 300) "fondu du theme, derniere image"
Assert-Equal "250 250 250" ($script:Ink.Bg -join " ") "fondu du theme termine"
Assert-True (-not (Update-InkFade 400)) "fondu du theme, plus rien a dessiner"
Assert-Equal "232 234 237" ($script:Palettes["dark"].Text -join " ") "palette d'origine intacte"
$script:Ink = $savedInk
