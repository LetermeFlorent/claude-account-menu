. (Join-Path $bin "claude-text.ps1")

$dtFiles = @(Get-ChildItem -LiteralPath $bin -Filter "claude-drive-*.ps1") + @(Get-Item -LiteralPath (Join-Path $bin "claude-cli-drive.ps1"))
$dtUsed = New-Object Collections.Generic.List[string]
foreach ($f in $dtFiles) {
  foreach ($m in [regex]::Matches([IO.File]::ReadAllText($f.FullName), 'Get-ClmText\s+"(drive\.[A-Za-z0-9.]+)"')) { $dtUsed.Add($m.Groups[1].Value) }
}
$dtKeys = @($dtUsed | Sort-Object -Unique)
Assert-True ($dtKeys.Count -gt 50) "textes drive : cles trouvees dans les fichiers"
foreach ($code in @("en", "fr")) {
  $dtTable = ConvertFrom-JsonText ([IO.File]::ReadAllText((Join-Path (Join-Path $bin "lang") ($code + ".json")), [Text.Encoding]::UTF8))
  $dtMissing = @($dtKeys | Where-Object { $null -eq $dtTable[$_] })
  Assert-Equal "" ($dtMissing -join " ") ("textes drive : cles presentes en " + $code)
  $dtAll = @($dtTable.Keys | Where-Object { $_.StartsWith("drive.") })
  $dtUnused = @($dtAll | Where-Object { $dtKeys -notcontains $_ })
  Assert-Equal "" ($dtUnused -join " ") ("textes drive : aucune cle inutilisee en " + $code)
}

$dtFr = ConvertFrom-JsonText ([IO.File]::ReadAllText((Join-Path (Join-Path $bin "lang") "fr.json"), [Text.Encoding]::UTF8))
$dtBad = @($dtFr.Keys | Where-Object { $_.StartsWith("drive.") -and $dtFr[$_] -cmatch '\b(efface|reglages?|regler|enregistree|activee|coupee|connecte|refuses?|laissee|depasse|reessayer|recus?|supprimes|envoyes|echec|prevues|bloquee|preciser|interrompue|arretee|derniere|fenetre|a jour|a corriger|a supprimer|a regler|a la|reponse|illisible|inattendue|incoherente|telechargement)\b' })
Assert-Equal "" ($dtBad -join " ") "textes drive : francais avec ses accents"
$dtOdd = @($dtFr.Keys | Where-Object { $_.StartsWith("drive.") -and $dtFr[$_] -match '[\u00A0\u202F\u2019\u201C\u201D\u2014]' })
Assert-Equal "" ($dtOdd -join " ") "textes drive : aucun caractere typographique interdit"

$dtEn = ConvertFrom-JsonText ([IO.File]::ReadAllText((Join-Path (Join-Path $bin "lang") "en.json"), [Text.Encoding]::UTF8))
$dtWeb = @($dtKeys | Where-Object { $_ -match '^drive\.(tag|away|request|msg|notice|off|status|prefs|sync|warn|syncing|progress|lock|scope|auth|cred|config|state|login)' })
Assert-True ($dtWeb.Count -gt 40) "textes drive : cles montrees par la page web trouvees"
foreach ($k in $dtWeb) {
  $value = Get-ClmText $k @("x", "y", "z", "w") "en"
  Assert-Equal ([string]$dtEn[$k]).Replace("{0}", "x").Replace("{1}", "y").Replace("{2}", "z").Replace("{3}", "w") $value ("textes drive : anglais pour " + $k)
  Assert-True ($value -notmatch '[^\x20-\x7E]') ("textes drive : anglais sans accent pour " + $k)
}
$dtSame = @($dtWeb | Where-Object { $dtEn[$_] -ceq $dtFr[$_] })
Assert-Equal "drive.progress drive.tag.sync drive.tag.syncing" ($dtSame -join " ") "textes drive : seuls les textes sans mot different a l'identique"
