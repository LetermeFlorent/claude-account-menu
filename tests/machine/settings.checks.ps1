. (Join-Path $PSScriptRoot "settings-text.ps1")
$sl = '"statusLine": { "type": "command", "command": "pwsh -File \"/home/x/statusline.ps1\"" }'
$a = '"a": "x,}]{ \"q\""'
$b = '"b": [1, { "statusLine": 2 }]'
$ab = New-SettingsText @($a, $b)
Assert-Equal $ab (Remove-MachineSettings (New-SettingsText @($a, $sl, $b))) "statusLine retire au milieu"
Assert-Equal $ab (Remove-MachineSettings (New-SettingsText @($sl, $a, $b))) "statusLine retire en tete"
Assert-Equal $ab (Remove-MachineSettings (New-SettingsText @($a, $b, $sl))) "statusLine retire en fin"
Assert-Equal $ab (Remove-MachineSettings (New-SettingsText @($sl, $a, $sl, $b))) "statusLine en double retire"
Assert-Equal "{}`n" (Remove-MachineSettings (New-SettingsText @($sl))) "statusLine seul retire"
Assert-Equal '{}' (Remove-MachineSettings '{}') "objet vide inchange"
Assert-Equal $ab (Remove-MachineSettings $ab) "statusLine imbrique jamais touche"
Assert-Equal '{"a": "statusLine"}' (Remove-MachineSettings '{"a": "statusLine"}') "valeur statusLine jamais prise pour une cle"
Assert-Equal '{"statusLine": {"type": 1' (Remove-MachineSettings '{"statusLine": {"type": 1') "JSON tronque rendu tel quel"
Assert-Equal '[{"statusLine": 1}]' (Remove-MachineSettings '[{"statusLine": 1}]') "tableau rendu tel quel"

$withSl = Add-MachineSettings $ab @($sl)
Assert-Equal (New-SettingsText @($a, $b, $sl)) $withSl "statusLine du PC remis en fin d'objet"
Assert-Equal $ab (Remove-MachineSettings $withSl) "retrait apres ajout : texte d'origine"
Assert-Equal "{`n  $sl`n}" (Add-MachineSettings '{}' @($sl)) "statusLine ajoute dans un objet vide"
Assert-Equal '{}' (Remove-MachineSettings (Add-MachineSettings '{}' @($sl))) "objet vide : retrait apres ajout"
Assert-Equal 'a1' (Add-MachineSettings 'a1' @($sl)) "JSON invalide : rien ajoute"
$got = Get-MachineSettings (New-SettingsText @($a, $sl, $b))
Assert-Equal 1 $got.Count "statusLine lu parmi les reglages"
Assert-Equal $sl $got[0] "statusLine lu tel quel"
Assert-Equal 0 (Get-MachineSettings 'a1').Count "JSON invalide : aucun reglage lu"

$winSeed = Get-SeedHookCommand "Windows"
Assert-Equal 'C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME/.local/bin/claude-statusline-seed.ps1"' $winSeed "commande du hook sous Windows"
Assert-Equal '/usr/local/bin/pwsh -NoProfile -File "$HOME/.local/bin/claude-statusline-seed.ps1"' (Get-SeedHookCommand "MacOS" "/usr/local/bin/pwsh") "commande du hook sous macOS"
$savedRoot = $env:SystemRoot
try {
  $env:SystemRoot = "C:\WINDOWS"
  $upperRoot = Get-PowerShellExe "Windows"
  $env:SystemRoot = "D:\WinNT\"
  $otherRoot = Get-PowerShellExe "Windows"
} finally { $env:SystemRoot = $savedRoot }
Assert-Equal "C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" $upperRoot "powershell : chemin absolu, casse de Windows sans effet"
Assert-Equal "D:/WinNT/System32/WindowsPowerShell/v1.0/powershell.exe" $otherRoot "powershell : chemin absolu sous un autre dossier Windows"
if ($script:OsName -ne "Windows") { Assert-True ((Get-PowerShellExe $script:OsName).StartsWith("/")) "pwsh : chemin absolu" }
$stale = New-SettingsText @((New-SeedHooksMember 'powershell -NoProfile -ExecutionPolicy Bypass -File "C:/Users/perso/.local/bin/claude-statusline-seed.ps1"'))
$canon = New-SettingsText @((New-SeedHooksMember $winSeed))
Assert-Equal $canon (Remove-MachineSettings $stale) "hook d'un autre PC remis sous forme canonique"
$savedOs = $script:OsName
$script:OsName = "Linux"
try { $linux = Add-MachineSettings $canon @() } finally { $script:OsName = $savedOs }
Assert-Equal (New-SettingsText @((New-SeedHooksMember (Get-SeedHookCommand "Linux")))) $linux "hook adapte a Linux en local"
Assert-Equal $canon (Remove-MachineSettings $linux) "hook Linux remis sous forme canonique a l'envoi"
$perm = '{"permissions": {"allow": ["Bash(pwsh /x/claude-statusline-seed.ps1)"]}}'
Assert-Equal $perm (Remove-MachineSettings $perm) "script du hook cite hors d'une commande : texte intact"

$utf8 = New-Object Text.UTF8Encoding($false)
$bom = [byte[]](@(0xEF, 0xBB, 0xBF) + $utf8.GetBytes((New-SettingsText @($a, $sl))))
$sent = Convert-SettingsBytes $bom
Assert-True (Test-Utf8Bom $sent) "BOM garde a l'envoi"
Assert-Equal (New-SettingsText @($a)) (ConvertFrom-SettingsBytes $sent) "envoi : statusLine retire malgre le BOM"
Assert-Equal ([Convert]::ToBase64String($bom)) ([Convert]::ToBase64String((Convert-SettingsBytes $sent @($sl) -Local))) "reception : statusLine du PC remis, BOM garde"
$odd = [byte[]](0x7B, 0x7D, 0xFF)
Assert-Equal ([Convert]::ToBase64String($odd)) ([Convert]::ToBase64String((Convert-SettingsBytes $odd))) "rien a changer : octets d'origine rendus"

Assert-True (Test-MachineSettingsPath ".claude/settings.json") "reglages du premier compte reperes"
Assert-True (Test-MachineSettingsPath ".claude-compte2/settings.json") "reglages d'un autre compte reperes"
Assert-True (-not (Test-MachineSettingsPath ".claude/projects/p/settings.json")) "autre settings.json ignore"
Assert-True (-not (Test-MachineSettingsPath ".claude.json")) "config globale ignoree"

$p1 = New-SandboxFile "machine/.claude/settings.json" (New-SettingsText @($a, $sl))
$p2 = New-SandboxFile "machine/.claude-compte2/settings.json" $ab
$p3 = Join-Path $script:Sandbox "machine/.claude-compte3/settings.json"
$p4 = Join-Path $script:Sandbox "neuf/.claude/settings.json"
Assert-Null (Read-MachineSettings $p3) "reglages absents : rien a garder"
$snap = Get-MachineSnapshot @($p1, $p2, $p3) $p1
$fresh = Get-MachineSnapshot @($p4) (Join-Path $script:Sandbox "neuf/absent.json")
Assert-Equal $sl (@($snap[$p3]) -join "|") "compte absent du PC : statusLine du premier compte"
$other = '"statusLine": { "type": "command", "command": "C:/Users/perso/statusline.exe" }'
[IO.File]::WriteAllText($p1, $ab)
[IO.File]::WriteAllText($p2, (New-SettingsText @($a, $other)))
$null = New-SandboxFile "machine/.claude-compte3/settings.json" (New-SettingsText @($a, $other))
$null = New-SandboxFile "neuf/.claude/settings.json" (New-SettingsText @($a, $other))
Restore-MachineSnapshot $snap
Restore-MachineSnapshot $fresh
Assert-Equal (New-SettingsText @($a, $b, $sl)) ([IO.File]::ReadAllText($p1)) "restauration : statusLine du PC garde"
Assert-Equal (New-SettingsText @($a)) ([IO.File]::ReadAllText($p2)) "restauration : statusLine de la sauvegarde ecarte"
Assert-Equal (New-SettingsText @($a, $sl)) ([IO.File]::ReadAllText($p3)) "restauration d'un compte neuf : statusLine du premier compte"
Assert-Equal (New-SettingsText @($a)) ([IO.File]::ReadAllText($p4)) "restauration sur un PC neuf : aucun statusLine"
