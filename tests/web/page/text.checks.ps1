. (Join-Path $bin "core/claude-text.ps1")

$txRoot = Join-Path $bin "lang"
$txPage = Join-Path $bin "clm-web"
$txTables = @{}
$txRaw = @{}
foreach ($code in @("en", "fr")) {
  $bytes = [IO.File]::ReadAllBytes((Join-Path $txRoot ($code + ".json")))
  $txRaw[$code] = [Text.Encoding]::UTF8.GetString($bytes)
  $txTables[$code] = ConvertFrom-JsonText $txRaw[$code]
  Assert-True (-not ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB)) ("textes " + $code + " : UTF-8 sans BOM")
  Assert-True (-not $txRaw[$code].Contains("`r")) ("textes " + $code + " : fins de ligne LF")
  $keys = @([regex]::Matches($txRaw[$code], '(?m)^  "([^"]+)":') | ForEach-Object { $_.Groups[1].Value })
  $sorted = [string[]]$keys.Clone()
  [Array]::Sort($sorted, [StringComparer]::Ordinal)
  Assert-Equal ($sorted -join " ") ($keys -join " ") ("textes " + $code + " : cles triees")
  $badLines = @($txRaw[$code].Split("`n") | Where-Object { $_ -ne "" -and $_ -ne "{" -and $_ -ne "}" -and $_ -notmatch '^  "[a-z]+\.[A-Za-z0-9.]+": ".*",?$' })
  Assert-Equal "" ($badLines -join " | ") ("textes " + $code + " : une cle par ligne, retrait de deux espaces, valeurs en texte")
  $odd = @($txRaw[$code].ToCharArray() | Where-Object { @(0x2014, 0x2013, 0x2018, 0x2019, 0x201C, 0x201D, 0x00A0, 0x202F, 0x2009, 0x200B, 0xFEFF, 0x00AB, 0x00BB) -contains [int]$_ })
  Assert-Equal 0 $odd.Count ("textes " + $code + " : aucun caractere typographique interdit")
}
$txEn = @($txTables["en"].Keys | Sort-Object)
$txFr = @($txTables["fr"].Keys | Sort-Object)
Assert-Equal ($txEn -join " ") ($txFr -join " ") "textes : memes cles en anglais et en francais"
$txHoleOf = { param([string]$Text) return (@([regex]::Matches($Text, '\{[0-9]\}') | ForEach-Object { $_.Value } | Sort-Object) -join "") }
$txHoles = @($txEn | Where-Object { (& $txHoleOf $txTables["en"][$_]) -ne (& $txHoleOf $txTables["fr"][$_]) })
Assert-Equal "" ($txHoles -join " ") "textes : memes valeurs a placer dans les deux langues"
Assert-True ($txTables["fr"]["server.autoOff"].Contains([string][char]0xE9)) "textes : accents francais intacts"
Assert-True (-not $txRaw["fr"].Contains([string][char]0xC3)) "textes : aucun accent abime"

$txCode = (@(Get-ChildItem -LiteralPath $txPage -Recurse -File -Include "*.js", "*.html" | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) -join "`n")
$txWanted = New-Object Collections.Generic.List[string]
foreach ($m in [regex]::Matches($txCode, '(?:data-text|data-label)"?[=:]\s*"([a-zA-Z.]+[a-zA-Z])"')) { $txWanted.Add("web." + $m.Groups[1].Value) }
foreach ($m in [regex]::Matches($txCode, 'clmText\("([a-zA-Z.]+[a-zA-Z])"')) { $txWanted.Add("web." + $m.Groups[1].Value) }
foreach ($m in [regex]::Matches($txCode, '"(backups\.warn[A-Za-z]+)"')) { $txWanted.Add("web." + $m.Groups[1].Value) }
foreach ($k in @("quota.q5", "quota.q7", "settings.palette.auto", "settings.palette.dark", "settings.palette.light", "settings.anim.auto", "settings.anim.on", "settings.anim.off")) { $txWanted.Add("web." + $k) }
$txServer = (@(Get-ChildItem -LiteralPath $bin -Filter "*.ps1" -Recurse | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) -join "`n")
foreach ($m in [regex]::Matches($txServer, '"(server\.[A-Za-z]+)"')) { $txWanted.Add($m.Groups[1].Value) }
Assert-True ($txWanted.Count -gt 100) "textes : cles de la page et du serveur trouvees"
$txMissing = @($txWanted | Sort-Object -Unique | Where-Object { $txEn -notcontains $_ })
Assert-Equal "" ($txMissing -join " ") "textes : chaque cle de la page et du serveur dans les fichiers de langue"

Assert-Equal "backup saved: x.zip" (Get-ClmText "server.saved" @("x.zip") "en") "textes : valeur placee en anglais"
Assert-Equal ("sauvegarde enregistr" + [char]0xE9 + "e : x.zip") (Get-ClmText "server.saved" @("x.zip") "fr") "textes : valeur placee en francais"
Assert-Equal "server.rien" (Get-ClmText "server.rien" @() "fr") "textes : cle inconnue rendue telle quelle"
Assert-Equal (Get-ClmText "server.busy" @() "en") (Get-ClmText "server.busy" @() "de") "textes : langue inconnue, anglais"

$txKept = $script:TextTables
try {
  $null = New-SandboxFile "text-root/en.json" '{"server.a":"one {0}","server.b":"two"}'
  $null = New-SandboxFile "text-root/fr.json" '{"server.a":"un {0}"}'
  Set-ClmTexts (Join-Path $script:Sandbox "text-root")
  Assert-Equal "un 1" (Get-ClmText "server.a" @(1) "fr") "textes : table francaise lue"
  Assert-Equal "two" (Get-ClmText "server.b" @() "fr") "textes : cle absente en francais, anglais"
  Set-ClmTexts (Join-Path $script:Sandbox "text-absent")
  Assert-Equal "server.a" (Get-ClmText "server.a" @() "fr") "textes : fichiers absents sans erreur"
} finally { $script:TextTables = $txKept }
