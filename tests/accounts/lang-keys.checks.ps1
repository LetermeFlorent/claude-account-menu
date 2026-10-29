$langTables = @{}
foreach ($code in @("en", "fr")) {
  $langTables[$code] = ConvertFrom-JsonText ([IO.File]::ReadAllText((Join-Path (Join-Path $bin "lang") ($code + ".json")), [Text.Encoding]::UTF8))
}
$langOwnedPatterns = @("claude-account*.ps1", "claude-cli.ps1", "claude-cli-accounts.ps1", "claude-cli-help.ps1", "claude-menu-remove.ps1", "claude-menu-rename.ps1", "claude-registry.ps1", "claude-credentials.ps1", "claude-keychain.ps1", "claude-platform.ps1", "claude-network.ps1", "claude-state*.ps1", "claude-json*.ps1", "claude-file-io.ps1", "claude-machine-*.ps1")
$langUsedKeys = @{}
foreach ($pattern in $langOwnedPatterns) {
  foreach ($f in Get-ChildItem -LiteralPath $bin -Filter $pattern -File) {
    $text = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
    foreach ($m in [regex]::Matches($text, '"((?:accounts|cli)\.[A-Za-z0-9.]+)"')) { if ($m.Groups[1].Value -notmatch '\.json$') { $langUsedKeys[$m.Groups[1].Value] = $f.Name } }
  }
}
Assert-True ($langUsedKeys.Count -gt 40) "textes comptes : des cles sont trouvees dans les fichiers"
foreach ($key in ($langUsedKeys.Keys | Sort-Object)) {
  foreach ($code in @("en", "fr")) {
    Assert-True ($null -ne $langTables[$code][$key] -and ([string]$langTables[$code][$key]).Length -gt 0) ("textes comptes : cle " + $key + " presente en " + $code + " (" + $langUsedKeys[$key] + ")")
  }
}

function Get-OwnedLangKeys {
  param($Table)
  return @($Table.Keys | Where-Object { $_ -cmatch '^(accounts|cli)\.' } | Sort-Object)
}
$langEnKeys = Get-OwnedLangKeys $langTables["en"]
$langFrKeys = Get-OwnedLangKeys $langTables["fr"]
Assert-Equal "" ((@($langEnKeys | Where-Object { $langFrKeys -cnotcontains $_ }) -join ",")) "textes comptes : cles anglaises sans traduction francaise"
Assert-Equal "" ((@($langFrKeys | Where-Object { $langEnKeys -cnotcontains $_ }) -join ",")) "textes comptes : cles francaises sans texte anglais"

$langBadChars = @([char]0x00A0, [char]0x202F, [char]0x2018, [char]0x2019, [char]0x201C, [char]0x201D, [char]0x2014)
foreach ($code in @("en", "fr")) {
  $badKeys = @()
  foreach ($key in (Get-OwnedLangKeys $langTables[$code])) {
    $value = [string]$langTables[$code][$key]
    foreach ($c in $langBadChars) { if ($value.Contains([string]$c)) { $badKeys += $key; break } }
  }
  Assert-Equal "" ($badKeys -join ",") ("textes comptes : typographie propre en " + $code)
}

$langUnaccentedPatterns = @(" deja ", "^deja ", "reseau", "reglages", "Telechargements", "Entree ", "Echap", "ecriture", "gardee", "a jour", "a cote", "privee", "reservee", "securite", "rangee", "repond", "annule$", "efface$", "dossier efface")
$unaccented = @()
foreach ($key in $langFrKeys) {
  $value = [string]$langTables["fr"][$key]
  foreach ($p in $langUnaccentedPatterns) { if ($value -cmatch $p) { $unaccented += ($key + " [" + $p + "]") } }
}
Assert-Equal "" ($unaccented -join "; ") "textes comptes : aucune valeur francaise sans accents"
