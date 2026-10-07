$themeHome = Join-Path $script:Sandbox "theme-home"
$vars = @{ USERPROFILE = $themeHome; HOME = $themeHome }

Assert-Equal "light" (ConvertTo-ThemeName "CLAIR" -French) "STATUSLINE_BG clair"
Assert-Equal "dark" (ConvertTo-ThemeName " Sombre " -French) "STATUSLINE_BG sombre"
Assert-Null (ConvertTo-ThemeName "clair") "clair refuse hors variable d'environnement"
Assert-Null (ConvertTo-ThemeName "auto") "auto declenche la detection"

$vars["STATUSLINE_BG"] = "Light"
Assert-Equal "light" (Get-ThemeName $script:OsName $vars) "etape 1, variable d'environnement"
$vars["STATUSLINE_BG"] = "rouge"
$null = New-SandboxFile "theme-home/.claude/statusline.json" '{"terminal_background":"DARK","gradient":{"5h":0.5}}'
Assert-Equal "dark" (Get-ThemeName $script:OsName $vars) "etape 2, statusline.json"
$null = New-SandboxFile "theme-home/.claude/statusline.json" '{"terminal_background":"Light"}'
Assert-Equal "light" (Get-ThemeName $script:OsName $vars) "etape 2, casse ignoree"
$vars.Remove("STATUSLINE_BG")
$null = New-SandboxFile "theme-home/.claude/statusline.json" '{"terminal_background":"auto"}'
Assert-Null (Get-ConfigTheme $themeHome) "auto dans statusline.json"
Assert-True (@("light", "dark") -contains (Get-ThemeName $script:OsName $vars)) "auto, detection jusqu'au systeme"

if ($script:OsName -eq "Windows") {
  $fake = @{ ok = "@echo light`r`n@exit /b 0`r`n"; old = "@echo usage: statusline`r`n@exit /b 2`r`n"; junk = "@echo bleu`r`n@exit /b 0`r`n" }
  $ext = ".cmd"
} else {
  $fake = @{ ok = "#!/bin/sh`necho light`nexit 0`n"; old = "#!/bin/sh`necho usage: statusline`nexit 2`n"; junk = "#!/bin/sh`necho bleu`nexit 0`n" }
  $ext = ".sh"
}
foreach ($k in @("ok", "old", "junk")) {
  $p = New-SandboxFile ("theme-bin/" + $k + $ext) $fake[$k]
  if ($script:OsName -ne "Windows") { & chmod +x $p }
}
Assert-Equal "light" (Get-BinaryTheme (Join-Path $script:Sandbox ("theme-bin/ok" + $ext))) "etape 3, binaire --theme"
Assert-Null (Get-BinaryTheme (Join-Path $script:Sandbox ("theme-bin/old" + $ext))) "etape 3, ancien binaire code 2"
Assert-Null (Get-BinaryTheme (Join-Path $script:Sandbox ("theme-bin/junk" + $ext))) "etape 3, sortie inattendue"
Assert-Null (Get-BinaryTheme (Join-Path $script:Sandbox "theme-bin/absent")) "etape 3, binaire absent"
Assert-Equal "/home/u/.claude/bin/statusline" (Get-StatuslineBinary "/home/u" "Linux") "chemin du binaire Unix"
Assert-Equal "C:\Users\u\.claude\bin\statusline.exe" (Get-StatuslineBinary "C:\Users\u" "Windows") "chemin du binaire Windows"

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
