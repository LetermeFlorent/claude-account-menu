. Import-ClmModule claude-ui-console-theme
$consoleHome = Join-Path $script:Sandbox "console-theme-home"
$consoleVars = @{ USERPROFILE = $consoleHome; HOME = $consoleHome; LOCALAPPDATA = (Join-Path $consoleHome "local") }

Assert-Equal "dark" (ConvertFrom-ColorFgBg "15;0") "COLORFGBG : fond 0 sombre"
Assert-Equal "dark" (ConvertFrom-ColorFgBg "7;8") "COLORFGBG : fond 8 sombre"
Assert-Equal "dark" (ConvertFrom-ColorFgBg "15;6") "COLORFGBG : fond 6 sombre"
Assert-Equal "light" (ConvertFrom-ColorFgBg "0;15") "COLORFGBG : fond 15 clair"
Assert-Equal "light" (ConvertFrom-ColorFgBg "0;7") "COLORFGBG : fond 7 clair"
Assert-Equal "light" (ConvertFrom-ColorFgBg "0;9") "COLORFGBG : fond 9 clair"
Assert-Equal "dark" (ConvertFrom-ColorFgBg "15;default;0") "COLORFGBG : trois champs, le dernier compte"
Assert-Equal "" (ConvertFrom-ColorFgBg "15;default") "COLORFGBG : fond par defaut inconnu"
Assert-Equal "" (ConvertFrom-ColorFgBg "0;42") "COLORFGBG : fond hors des 16 couleurs inconnu"
Assert-Equal "" (ConvertFrom-ColorFgBg "") "COLORFGBG : absente"

$script:oscAsked = 0
$darkReply = { $script:oscAsked++; return ([string][char]27 + "]11;rgb:0c0c/0c0c/0c0c" + [char]7 + [char]27 + "[?1;0c") }
$termVars = $consoleVars.Clone()
$termVars["COLORFGBG"] = "0;15"
$termVars["TERM"] = "xterm-256color"
Assert-Equal "light" (Get-TerminalTheme "Linux" $termVars $true $darkReply) "terminal : COLORFGBG passe avant la question OSC"
Assert-Equal 0 $script:oscAsked "terminal : pas de question OSC quand COLORFGBG repond"
$termVars.Remove("COLORFGBG")
Assert-Equal "dark" (Get-TerminalTheme "Linux" $termVars $true $darkReply) "terminal : fond lu par la question OSC"
Assert-Equal "" (Get-TerminalTheme "Linux" $termVars $false $darkReply) "terminal : pas de question hors terminal"
$wtDir = Join-Path $consoleHome "local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
$null = New-SandboxFile "console-theme-home/local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json" '{ "defaultProfile": "{a}", "profiles": { "list": [ { "guid": "{a}", "colorScheme": "One Half Light" } ] } }'
$wtVars = $consoleVars.Clone()
$wtVars["WT_SESSION"] = "x"
$script:oscAsked = 0
Assert-Equal "light" (Get-TerminalTheme "Windows" $wtVars $true $darkReply) "terminal : schema de Windows Terminal avant la question OSC"
Assert-Equal 0 $script:oscAsked "terminal : pas de question OSC quand Windows Terminal repond"
Remove-Item -LiteralPath $wtDir -Recurse -Force

$savedTerminal = $script:TerminalTheme
$script:TerminalTheme = $null
$script:systemAsked = 0
$sys = { param($O, $V) $script:systemAsked++; "light" }
Assert-Equal "dark" (Get-AutoTheme "Linux" $consoleVars { param($O, $V) "dark" } $sys) "auto : fond du terminal d'abord"
Assert-Equal 0 $script:systemAsked "auto : systeme pas lu quand le terminal repond"
Assert-Equal "dark" (Get-AutoTheme "Linux" $consoleVars { param($O, $V) "light" } $sys) "auto : fond du terminal lu une seule fois"
$script:TerminalTheme = $null
Assert-Equal "light" (Get-AutoTheme "Linux" $consoleVars { param($O, $V) "" } $sys) "auto : theme du systeme ensuite"
$script:TerminalTheme = $null
Assert-Equal "dark" (Get-AutoTheme "Linux" $consoleVars { param($O, $V) "" } { param($O, $V) "" }) "auto : sombre par defaut, systeme vide"
Assert-Equal "dark" (Get-AutoTheme "Linux" $consoleVars { param($O, $V) "" } { param($O, $V) $null }) "auto : sombre par defaut, systeme inconnu"
$script:TerminalTheme = $null
Assert-Equal "dark" (Get-AutoTheme "Linux" $consoleVars { throw "panne" } { throw "panne" }) "auto : pannes des lecteurs sans erreur"
$script:TerminalTheme = "light"
$fixedVars = $consoleVars.Clone()
$fixedVars["STATUSLINE_BG"] = "sombre"
Assert-Equal "dark" (Get-ConsoleTheme "Linux" $fixedVars) "console : STATUSLINE_BG passe avant le terminal"
$null = New-SandboxFile "console-theme-home/.local/state/clm/display.json" '{ "palette": "dark" }'
$null = New-SandboxFile "console-theme-home/local/clm/display.json" '{ "palette": "dark" }'
$null = New-SandboxFile "console-theme-home/Library/Application Support/clm/display.json" '{ "palette": "dark" }'
Assert-Equal "dark" (Get-ConsoleTheme $script:OsName $consoleVars) "console : palette fixee dans les reglages avant le terminal"
$script:TerminalTheme = $savedTerminal
