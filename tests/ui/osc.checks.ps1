. Import-ClmModule claude-ui-osc

$esc = [string][char]27
$bel = [string][char]7
$st = $esc + "\"
$da = $esc + "[?61;4;6;7;14;21;22;23;24;28;32;42c"
$darkReply = $esc + "]11;rgb:0c0c/0c0c/0c0c" + $st
$lightReply = $esc + "]11;rgb:fafa/fafa/fafa" + $bel

Assert-Equal ($esc + "]11;?" + $st + $esc + "[c") $script:OscQuery "OSC 11 : requete suivie d'une demande DA1"

Assert-Equal "12,12,12" ((ConvertFrom-OscReply $darkReply) -join ",") "OSC 11 : reponse sur quatre chiffres"
Assert-Equal "250,250,250" ((ConvertFrom-OscReply ($esc + "]11;rgb:fa/fa/fa" + $bel)) -join ",") "OSC 11 : reponse claire sur deux chiffres"
Assert-Equal "0,255,136" ((ConvertFrom-OscReply ($esc + "]11;rgb:0/f/8" + $st)) -join ",") "OSC 11 : reponse sur un chiffre"
Assert-Equal "255,128,0" ((ConvertFrom-OscReply ($esc + "]11;rgb:ffff/80/0" + $st)) -join ",") "OSC 11 : canaux de longueurs differentes"
Assert-Equal "253,246,227" ((ConvertFrom-OscReply ($esc + "]11;rgba:fdfd/f6f6/e3e3/ffff" + $st)) -join ",") "OSC 11 : reponse rgba, quatrieme canal ignore"
Assert-Equal "250,250,250" ((ConvertFrom-OscReply $lightReply) -join ",") "OSC 11 : fin par BEL"
Assert-Equal "12,12,12" ((ConvertFrom-OscReply ($darkReply + $da)) -join ",") "OSC 11 : fin par ESC \ suivie de la reponse DA1"
Assert-Equal "12,12,12" ((ConvertFrom-OscReply ("]11;rgb:0c0c/0c0c/0c0c\[?61;4c")) -join ",") "OSC 11 : reponse dont les ESC sont perdus"
Assert-Null (ConvertFrom-OscReply ($esc + "]11;rgb:0c0c/0c0c/0c")) "OSC 11 : reponse tronquee refusee"
Assert-Null (ConvertFrom-OscReply ($esc + "]111;rgb:0c0c/0c0c/0c0c" + $st)) "OSC 11 : autre code OSC refuse"
Assert-Null (ConvertFrom-OscReply ($esc + "]11;rgb:0c0c0/0c0c/0c0c" + $st)) "OSC 11 : canal trop long refuse"
Assert-Null (ConvertFrom-OscReply "n'importe quoi") "OSC 11 : texte sans rapport refuse"
Assert-Null (ConvertFrom-OscReply "") "OSC 11 : reponse vide"
Assert-Null (ConvertFrom-OscReply $null) "OSC 11 : reponse absente"

Assert-True (-not (Test-OscCapable -Os "Windows" -Vars @{} -Rich $true)) "OSC 11 : Windows sans WT_SESSION ni TERM_PROGRAM non interroge"
Assert-True (Test-OscCapable -Os "Windows" -Vars @{ WT_SESSION = "abc" } -Rich $true) "OSC 11 : Windows Terminal interroge"
Assert-True (Test-OscCapable -Os "Windows" -Vars @{ TERM_PROGRAM = "vscode" } -Rich $true) "OSC 11 : terminal de VS Code interroge"
Assert-True (Test-OscCapable -Os "Windows" -Vars @{ TERM_PROGRAM = "WezTerm" } -Rich $true) "OSC 11 : WezTerm interroge"
Assert-True (-not (Test-OscCapable -Os "Windows" -Vars @{ TERM_PROGRAM = "mintty" } -Rich $true)) "OSC 11 : TERM_PROGRAM hors liste non interroge sous Windows"
Assert-True (-not (Test-OscCapable -Os "Linux" -Vars @{ TERM = "screen-256color" } -Rich $true)) "OSC 11 : screen non interroge"
Assert-True (-not (Test-OscCapable -Os "MacOS" -Vars @{ TERM = "tmux-256color" } -Rich $true)) "OSC 11 : tmux non interroge"
Assert-True (-not (Test-OscCapable -Os "Windows" -Vars @{ WT_SESSION = "abc" } -Rich $false)) "OSC 11 : console sans VT ou redirigee non interrogee"
Assert-True (-not (Test-OscCapable -Os "Windows" -Vars @{ WT_SESSION = "abc"; TERM = "dumb" } -Rich $true)) "OSC 11 : TERM=dumb non interroge sous Windows"
Assert-True (-not (Test-OscCapable -Os "Windows" -Vars @{ WT_SESSION = "abc"; CLM_OSC = "0" } -Rich $true)) "OSC 11 : CLM_OSC=0 coupe la requete sous Windows"
Assert-True (Test-OscCapable -Os "Linux" -Vars @{ TERM = "xterm-256color" } -Rich $true) "OSC 11 : Linux avec TERM interroge"
Assert-True (Test-OscCapable -Os "MacOS" -Vars @{ TERM = "xterm-256color" } -Rich $true) "OSC 11 : macOS avec TERM interroge"
Assert-True (-not (Test-OscCapable -Os "Linux" -Vars @{} -Rich $true)) "OSC 11 : Linux sans TERM non interroge"
Assert-True (-not (Test-OscCapable -Os "Linux" -Vars @{ TERM = "dumb" } -Rich $true)) "OSC 11 : TERM=dumb non interroge"
Assert-True (-not (Test-OscCapable -Os "Linux" -Vars @{ TERM = "xterm-256color" } -Rich $false)) "OSC 11 : Linux sans tty non interroge"
Assert-True (-not (Test-OscCapable -Os "Linux" -Vars @{ TERM = "xterm-256color"; CLM_OSC = "0" } -Rich $true)) "OSC 11 : CLM_OSC=0 coupe la requete"
Assert-True (Test-OscCapable -Os "Linux" -Vars @{ TERM = "xterm"; CLM_OSC = "1" } -Rich $true) "OSC 11 : CLM_OSC=1 laisse la requete"

$script:OscReads = 0
$wt = @{ WT_SESSION = "abc" }
$readDark = { $script:OscReads++; return $darkReply + $da }
$readLight = { $script:OscReads++; return $lightReply + $da }
$readNothing = { $script:OscReads++; return "" }
$readThrow = { $script:OscReads++; throw "terminal muet" }
Assert-Equal "dark" (Get-OscTheme -Os "Windows" -Vars $wt -Rich $true -Reader $readDark) "OSC 11 : fond sombre lu"
Assert-Equal "light" (Get-OscTheme -Os "Linux" -Vars @{ TERM = "xterm" } -Rich $true -Reader $readLight) "OSC 11 : fond clair lu"
Assert-Equal "" (Get-OscTheme -Os "Windows" -Vars $wt -Rich $true -Reader $readNothing) "OSC 11 : terminal sans reponse donne inconnu"
Assert-Equal "" (Get-OscTheme -Os "Windows" -Vars $wt -Rich $true -Reader $readThrow) "OSC 11 : lecteur en erreur donne inconnu"
Assert-Equal 4 $script:OscReads "OSC 11 : le lecteur est appele quand le terminal sait repondre"
Assert-Equal "" (Get-OscTheme -Os "Windows" -Vars @{} -Rich $true -Reader $readDark) "OSC 11 : console classique donne inconnu"
Assert-Equal "" (Get-OscTheme -Os "Windows" -Vars $wt -Rich $false -Reader $readDark) "OSC 11 : sortie redirigee donne inconnu"
Assert-Equal "" (Get-OscTheme -Os "Linux" -Vars @{ TERM = "xterm"; CLM_OSC = "0" } -Rich $true -Reader $readDark) "OSC 11 : CLM_OSC=0 donne inconnu"
Assert-Equal 4 $script:OscReads "OSC 11 : le lecteur n'est jamais appele sans terminal capable"
Assert-Equal "12,12,12" ((Read-OscBackground -Os "Linux" -Reader $readDark) -join ",") "OSC 11 : couleur lue par le lecteur injecte"
Assert-Null (Read-OscBackground -Os "Windows" -Reader $readThrow) "OSC 11 : lecteur en erreur sans exception"
Assert-Equal "Read-ConsoleReply" (Get-OscReaderName "Windows") "OSC 11 : lecteur de console sous Windows"
Assert-Equal "Read-TtyReply" (Get-OscReaderName "Linux") "OSC 11 : lecteur tty sous Linux"
Assert-Equal "Read-TtyReply" (Get-OscReaderName "MacOS") "OSC 11 : lecteur tty sous macOS"

function Reset-FakeKeys {
  param([object[]]$Items, [int]$Step)
  $script:FakeKeys = New-Object System.Collections.Queue
  foreach ($i in $Items) { $script:FakeKeys.Enqueue($i) }
  $script:FakeMs = 0
  $script:FakeStep = $Step
}

function Split-FakeText {
  param([string]$Text)
  return @($Text.ToCharArray() | ForEach-Object { [string]$_ })
}

$testKey = {
  if ($script:FakeKeys.Count -gt 0 -and $null -ne $script:FakeKeys.Peek()) { return $true }
  if ($script:FakeKeys.Count -gt 0) { [void]$script:FakeKeys.Dequeue() }
  $script:FakeMs += $script:FakeStep
  return $false
}
$readKey = { return [string]$script:FakeKeys.Dequeue() }
$clock = { return $script:FakeMs }
$boom = { throw "console fermee" }

Reset-FakeKeys (@(Split-FakeText ($esc + "]11;rgb:0c")) + @($null, $null) + @(Split-FakeText ("0c/0c0c/0c0c" + $st)) + @($null) + @(Split-FakeText $da)) 1
$got = Read-ReplyText @{ TestKey = $testKey; ReadKey = $readKey; Clock = $clock }
Assert-Equal ($darkReply + $da) $got "OSC 11 : reponse arrivee en morceaux lue en entier"
Assert-Equal "12,12,12" ((ConvertFrom-OscReply $got) -join ",") "OSC 11 : reponse en morceaux decodee"

Reset-FakeKeys (@(Split-FakeText $da) + @("z", "z")) 1
Assert-Equal $da (Read-ReplyText @{ TestKey = $testKey; ReadKey = $readKey; Clock = $clock }) "OSC 11 : arret des la reponse DA1 seule"
Assert-Equal 2 $script:FakeKeys.Count "OSC 11 : rien n'est lu apres la reponse DA1"
Assert-Equal 0 $script:FakeMs "OSC 11 : la reponse DA1 seule n'attend pas"

Reset-FakeKeys @() 40
Assert-Equal "" (Read-ReplyText @{ TestKey = $testKey; ReadKey = $readKey; Clock = $clock }) "OSC 11 : terminal muet donne une reponse vide"
Assert-Equal 160 $script:FakeMs "OSC 11 : terminal muet arrete apres 100 ms puis 50 ms de calme"

Reset-FakeKeys (@($null, $null, $null) + @(Split-FakeText ($darkReply + "[?6"))) 40
Assert-Equal ($darkReply + "[?6") (Read-ReplyText @{ TestKey = $testKey; ReadKey = $readKey; Clock = $clock }) "OSC 11 : reponse en retard videe pendant le calme"
Assert-Equal 0 $script:FakeKeys.Count "OSC 11 : aucun octet en retard laisse en entree"

$script:FakeMs = 0
$flood = Read-ReplyText @{ TestKey = { $true }; ReadKey = { $script:FakeMs += 10; "x" }; Clock = $clock }
Assert-Equal 250 $script:FakeMs "OSC 11 : un flot de touches s'arrete a la borne dure de 250 ms"
Assert-Equal 25 $flood.Length "OSC 11 : un flot de touches n'est lu que jusqu'a la borne"

Reset-FakeKeys (@(Split-FakeText "abc")) 1
Assert-Equal "" (Read-ReplyText @{ TestKey = $testKey; ReadKey = $boom; Clock = $clock }) "OSC 11 : source de touches en erreur sans exception"
Assert-Equal "" (Read-ReplyText @{ TestKey = $boom; ReadKey = $readKey; Clock = $clock }) "OSC 11 : test de touche en erreur sans exception"

$hexReply = " 1b 5d 31 31 3b 72 67 62 3a 30 63 30 63 2f 30 63 30 63 2f 30 63 30 63 1b 5c`n 1b 5b 3f 36 31 3b 34 3b 36 3b 37 3b 31 34 3b 32 31 3b 32 32 3b 32 33 3b 32 34 3b 32 38 3b 33 32 3b 34 32 63"
Assert-Equal ($darkReply + $da) (ConvertFrom-ByteHex $hexReply) "OSC 11 : octets du tty decodes depuis l'hexadecimal"
Assert-Equal "" (ConvertFrom-ByteHex "zz 1b") "OSC 11 : hexadecimal invalide ignore"
Assert-Equal "" (ConvertFrom-ByteHex "") "OSC 11 : aucun octet lu"
Assert-True (-not (Get-TtyScript).Contains("`r")) "OSC 11 : script tty sans retour chariot"

$fakeShell = {
  param([string]$Script, [string[]]$Arguments, [int]$LimitMs)
  $kind = "main"
  if ($Script -eq $script:TtySaveScript) { $kind = "save" }
  if ($Script -eq $script:TtyRestoreScript) { $kind = "restore" }
  $script:ShellLog += ($kind + ":" + @($Arguments)[-1] + ":" + $LimitMs)
  if ($kind -eq "save") { return $script:ShellSave }
  if ($kind -eq "main") { return $script:ShellMain }
  return ""
}
$script:ShellLog = @(); $script:ShellSave = "500:5:bf:8a3b`n"; $script:ShellMain = $null
Assert-Equal "" (Read-TtyReply -Shell $fakeShell) "OSC 11 : tty hors delai donne une reponse vide"
Assert-Equal "save::200|main:500:5:bf:8a3b:500|restore:500:5:bf:8a3b:200" ($script:ShellLog -join "|") "OSC 11 : tty hors delai remis dans son etat sauve"
$script:ShellLog = @(); $script:ShellMain = $hexReply
Assert-Equal ($darkReply + $da) (Read-TtyReply -Shell $fakeShell) "OSC 11 : reponse lue par le shell tty"
Assert-Equal "save::200|main:500:5:bf:8a3b:500" ($script:ShellLog -join "|") "OSC 11 : pas de remise en etat apres une sortie normale"
$script:ShellLog = @(); $script:ShellSave = $null
Assert-Equal "" (Read-TtyReply -Shell $fakeShell) "OSC 11 : sans tty rien n'est envoye"
Assert-Equal "save::200" ($script:ShellLog -join "|") "OSC 11 : sans etat sauve la requete n'est pas lancee"
