$win = @{ USERPROFILE = "C:\Users\u"; LOCALAPPDATA = "C:\Users\u\AppData\Local" }
$mac = @{ HOME = "/Users/u" }
$lin = @{ HOME = "/home/u" }
$xdg = @{ HOME = "/home/u"; XDG_STATE_HOME = "/var/st/"; XDG_CACHE_HOME = "/var/ca" }

Assert-Equal "C:\Users\u" (Get-HomeDir @{ USERPROFILE = "C:\Users\u"; HOME = "C:\h" }) "home : USERPROFILE avant HOME"
Assert-Equal "/home/u" (Get-HomeDir $lin) "home : HOME a defaut"
Assert-Equal "C:\Users\u\AppData\Local" (Get-LocalAppData @{ USERPROFILE = "C:\Users\u" }) "LOCALAPPDATA de repli"

Assert-Equal "C:\Users\u\AppData\Local\claude-statusline\state" (Get-StatusStatePath "Windows" $win) "etat Windows"
Assert-Equal "/Users/u/Library/Application Support/claude-statusline/state" (Get-StatusStatePath "MacOS" $mac) "etat macOS"
Assert-Equal "/home/u/.local/state/claude-statusline/state" (Get-StatusStatePath "Linux" $lin) "etat Linux"
Assert-Equal "/var/st/claude-statusline/state" (Get-StatusStatePath "Linux" $xdg) "etat Linux XDG_STATE_HOME"

Assert-Equal "C:\Users\u\AppData\Local\claude-menu\usage.json" (Get-UsageCachePath "Windows" $win) "cache Windows"
Assert-Equal "/Users/u/Library/Caches/claude-menu/usage.json" (Get-UsageCachePath "MacOS" $mac) "cache macOS"
Assert-Equal "/home/u/.cache/claude-menu/usage.json" (Get-UsageCachePath "Linux" $lin) "cache Linux"
Assert-Equal "/var/ca/claude-menu/usage.json" (Get-UsageCachePath "Linux" $xdg) "cache Linux XDG_CACHE_HOME"

Assert-Equal "C:\Users\u\.cache\claude\staging" (Get-StagingRoot "Windows" $win) "staging Windows"
Assert-Equal "C:\h\.cache\claude\staging" (Get-StagingRoot "Windows" @{ USERPROFILE = "C:\Users\u"; HOME = "C:\h" }) "staging : HOME avant le dossier personnel"
Assert-Equal "/var/ca/claude/staging" (Get-StagingRoot "Linux" $xdg) "staging XDG_CACHE_HOME"
Assert-Equal "/Users/u/.cache/claude/staging" (Get-StagingRoot "MacOS" $mac) "staging macOS"

Assert-Equal "claude.exe" (Get-ClaudeExeName "Windows") "executable Windows"
Assert-Equal "claude" (Get-ClaudeExeName "Linux") "executable Linux"
Assert-Equal "claude" (Get-ClaudeExeName "MacOS") "executable macOS"
Assert-Equal "/a/b/c" (Join-OsPath "Linux" @("/a/", "/b/", "c")) "Join-OsPath Unix"
Assert-Equal "C:\a\b" (Join-OsPath "Windows" @("C:\a\", "b")) "Join-OsPath Windows"
Assert-Equal "c:/users/u/.claude" (ConvertTo-PathKey "C:\Users\U\.claude\" "Windows") "cle de chemin Windows"
Assert-Equal "/home/U/.claude" (ConvertTo-PathKey "/home/U/.claude/" "Linux") "cle de chemin Unix sensible a la casse"

Assert-Equal "bsd" (Get-TarFlavor "bsdtar 3.7.2 - libarchive 3.7.2 zlib/1.2.13") "tar bsd"
Assert-Equal "gnu" (Get-TarFlavor "tar (GNU tar) 1.34") "tar gnu"
Assert-Equal ".zip" (Get-ArchiveExtension "bsd") "extension bsd"
Assert-Equal ".tar.gz" (Get-ArchiveExtension "gnu") "extension gnu"

$outLog = New-SandboxFile "tar.out.log" ".claude/settings.json`n.claude/agents/`n"
$errLog = New-SandboxFile "tar.err.log" "a .claude-compte2/x.json`r`nx .claude-compte2/y.json`r`ntar: avertissement`r`n"
Assert-Equal ".claude/settings.json|.claude/agents/|.claude-compte2/x.json|.claude-compte2/y.json" ((Get-TarEntries $outLog $errLog) -join "|") "entrees tar GNU et bsdtar"

Assert-Equal 0 ((Get-ProgressBar 0).Replace([string][char]0x25A1, "").Length) "barre 0 %"
Assert-Equal 10 ((Get-ProgressBar 50).Replace([string][char]0x25A1, "").Length) "barre 50 %"
Assert-Equal 20 ((Get-ProgressBar 150).Length) "barre bornee"
Assert-Equal 20 ((Get-ProgressBar 150).Replace([string][char]0x25A1, "").Length) "barre pleine au-dela de 100"
Assert-Equal 0 ((Get-WaitBar 0).IndexOf([string][char]0x25A0)) "attente, case 1"
Assert-Equal 1 ((Get-WaitBar 21).IndexOf([string][char]0x25A0)) "attente, la case avance et boucle"
Assert-Equal 20 ((Get-WaitBar 7).Length) "attente, largeur"

Assert-Equal "Claude Code-credentials" (Get-KeychainService "") "trousseau, compte par defaut"
Assert-Equal "Claude Code-credentials-e338690a" (Get-KeychainService "/Users/u/.claude-compte2") "trousseau, dossier de config"
$nfd = "/Users/u/.claude-compt" + "e" + [char]0x0301 + "e"
Assert-Equal "Claude Code-credentials-e6957510" (Get-KeychainService $nfd) "trousseau, normalisation NFC"
$chunks = @("eyJhIjox", "fQ==")
Assert-Equal '{"a":1}' (Join-KeychainChunks '{"n":2,"l":12}' { param($k) $chunks[$k] }) "trousseau, morceaux recolles"
Assert-Null (Join-KeychainChunks '{"n":2,"l":11}' { param($k) $chunks[$k] }) "trousseau, longueur fausse"
Assert-Null (Join-KeychainChunks '{"n":0,"l":12}' { param($k) $chunks[$k] }) "trousseau, n nul"
Assert-Null (Join-KeychainChunks '{"n":3,"l":12}' { param($k) $chunks[$k] }) "trousseau, morceau manquant"
Assert-Null (Join-KeychainChunks 'pas du json' { param($k) $chunks[$k] }) "trousseau, meta illisible"
