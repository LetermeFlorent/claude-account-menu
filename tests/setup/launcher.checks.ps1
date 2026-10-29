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

$shCmd = Get-Command sh -ErrorAction SilentlyContinue
if ($shCmd -and $script:OsName -ne "MacOS") {
  $shPath = $shCmd.Source
  $shRoot = Join-Path $script:Sandbox "sh-text"
  $shUtf8 = New-Object Text.UTF8Encoding($false)
  New-Item -ItemType Directory -Path $shRoot -Force | Out-Null
  $shLookup = Join-Path $shRoot "lookup.sh"
  $shRun = Join-Path $shRoot "run.sh"
  $shOut = Join-Path $shRoot "out.txt"
  [IO.File]::WriteAllText($shLookup, ". `"`$1/clm-text.sh`"`nCLM_LANG_DIR=`$2`nout=`$3`nshift 3`nclm_text `"`$@`" > `"`$out`"`n", $shUtf8)
  [IO.File]::WriteAllText($shRun, "exec 2> `"`$2`"`nexec sh `"`$1/clm`"`n", $shUtf8)

  function ConvertTo-ShPath { param([string]$Path) return $Path.Replace("\", "/") }

  function Invoke-ShEnv {
    param([hashtable]$Vars, [scriptblock]$Body)
    $saved = @{}
    foreach ($n in @("CLM_LANG", "LC_ALL", "LC_MESSAGES", "LANG")) { $saved[$n] = [Environment]::GetEnvironmentVariable($n); [Environment]::SetEnvironmentVariable($n, $Vars[$n]) }
    try { & $Body } finally { foreach ($n in $saved.Keys) { [Environment]::SetEnvironmentVariable($n, $saved[$n]) } }
  }

  function Get-ShText {
    param([hashtable]$Vars, [string]$LangDir, [string[]]$Words)
    Remove-Item -LiteralPath $shOut -Force -ErrorAction SilentlyContinue
    Invoke-ShEnv $Vars { & $shPath $shLookup (ConvertTo-ShPath $bin) (ConvertTo-ShPath $LangDir) (ConvertTo-ShPath $shOut) @Words | Out-Null }
    return ([IO.File]::ReadAllText($shOut, $shUtf8) -replace "[\r\n]+$", "")
  }

  function Get-ShLauncherErrors {
    param([hashtable]$Vars, [bool]$WithText)
    $dir = Join-Path $shRoot ("launcher" + [int]$WithText + ($Vars["CLM_LANG"]))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $launcher = [IO.File]::ReadAllText((Join-Path $bin "clm")).Replace("command -v pwsh", "command -v clm-absent-host")
    [IO.File]::WriteAllText((Join-Path $dir "clm"), $launcher, $shUtf8)
    if ($WithText) {
      Copy-Item -LiteralPath (Join-Path $bin "clm-text.sh") -Destination $dir
      Copy-Item -LiteralPath (Join-Path $bin "lang") -Destination $dir -Recurse
    }
    $errFile = Join-Path $dir "err.txt"
    Invoke-ShEnv $Vars { & $shPath $shRun (ConvertTo-ShPath $dir) (ConvertTo-ShPath $errFile) | Out-Null }
    $code = $LASTEXITCODE
    return [pscustomobject]@{ Code = $code; Text = ([IO.File]::ReadAllText($errFile, $shUtf8) -replace "[\r\n]+$", "") }
  }

  $shLang = Join-Path $bin "lang"
  $shArgs = @("install.sh.copied", "scripts copied to {0}", "/tmp/dest")
  $shNone = @{}
  Assert-Equal (Get-ClmText "install.sh.copied" @("/tmp/dest") "fr") (Get-ShText @{ CLM_LANG = "fr" } $shLang $shArgs) "sh : CLM_LANG=fr lit fr.json"
  Assert-Equal (Get-ClmText "install.sh.copied" @("/tmp/dest") "en") (Get-ShText @{ CLM_LANG = "en" } $shLang $shArgs) "sh : CLM_LANG=en lit en.json"
  Assert-Equal (Get-ClmText "install.sh.copied" @("/tmp/dest") "fr") (Get-ShText @{ LANG = "fr_FR.UTF-8"; LC_ALL = "C" } $shLang $shArgs) "sh : LC_ALL=C ignore, LANG=fr_FR donne fr"
  Assert-Equal (Get-ClmText "install.sh.copied" @("/tmp/dest") "en") (Get-ShText @{ LANG = "de_DE.UTF-8" } $shLang $shArgs) "sh : autre langue donne en"
  Assert-Equal (Get-ClmText "install.sh.copied" @("/tmp/dest") "en") (Get-ShText $shNone $shLang $shArgs) "sh : aucune variable donne en"
  Assert-Equal "scripts copied to /tmp/dest" (Get-ShText @{ CLM_LANG = "fr" } (Join-Path $shRoot "absent") $shArgs) "sh : dossier de langue absent, texte anglais de secours"
  Assert-Equal "nope a x a" (Get-ShText @{ CLM_LANG = "fr" } $shLang @("no.such.key", "nope {0} {1} {0}", "a", "x")) "sh : cle absente, texte de secours et valeurs"

  $shPartial = Join-Path $shRoot "partial"
  New-Item -ItemType Directory -Path $shPartial -Force | Out-Null
  [IO.File]::WriteAllText((Join-Path $shPartial "en.json"), "{`n  `"only.en`": `"english only {0}`"`n}`n", $shUtf8)
  Assert-Equal "english only 1" (Get-ShText @{ CLM_LANG = "fr" } $shPartial @("only.en", "fallback", "1")) "sh : fr.json absent, en.json lu"

  $shKeys = @("install.launcher.needPwsh", "install.launcher.macHint", "install.launcher.linuxHint")
  foreach ($shCode in @("fr", "en")) {
    $shExpected = (@(foreach ($k in $shKeys) { Get-ClmText $k @() $shCode }) -join "`n")
    $shLaunch = Get-ShLauncherErrors @{ CLM_LANG = $shCode } $true
    Assert-Equal 127 $shLaunch.Code ("clm sans pwsh (" + $shCode + ") : code 127")
    Assert-Equal $shExpected $shLaunch.Text ("clm sans pwsh (" + $shCode + ") : texte du fichier de langue")
  }
  $shBare = Get-ShLauncherErrors @{ CLM_LANG = "fr" } $false
  Assert-Equal 127 $shBare.Code "clm sans pwsh ni clm-text.sh : code 127"
  Assert-Equal ((@(foreach ($k in $shKeys) { Get-ClmText $k @() "en" }) -join "`n")) $shBare.Text "clm sans pwsh ni clm-text.sh : texte anglais de secours"
}
