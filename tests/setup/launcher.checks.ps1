$launcherMain = [IO.File]::ReadAllText((Join-Path $bin "clm.cmd"))
$launcherAlias = [IO.File]::ReadAllText((Join-Path $bin "claude-menu.cmd"))
$launcherAliasLines = @($launcherAlias -split "`r?`n" | Where-Object { $_.Trim() -ne "" })
$launcherRunLine = @($launcherMain -split "`r?`n" | Where-Object { $_.Contains('"%~dp0claude-menu.ps1" %*') })
$launcherBareHost = '(?i)(?<![\w\\])(pwsh|powershell)'
Assert-True ($launcherMain.Contains('%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"')) "clm.cmd : powershell windows par chemin absolu"
Assert-True ($launcherMain.Contains('if exist "%ProgramFiles%\PowerShell\7\pwsh.exe"')) "clm.cmd : pwsh 7 par chemin absolu quand il est installe"
Assert-Equal 0 ([regex]::Matches($launcherMain + $launcherAlias, $launcherBareHost)).Count "lanceurs cmd : aucun interpreteur cherche par son nom"
Assert-Equal 1 $launcherRunLine.Count "clm.cmd : une seule ligne lance le menu"
Assert-True ($launcherRunLine[0].EndsWith(" & call exit /b %%errorlevel%%")) "clm.cmd : sortie sur la ligne du menu, code du menu rendu"
Assert-True (-not $launcherAlias.Contains("claude-menu.ps1")) "claude-menu.cmd : aucune copie du lancement"
Assert-Equal '"%~dp0clm.cmd" %*' $launcherAliasLines[-1] "claude-menu.cmd : passe la main a clm.cmd en derniere ligne"
