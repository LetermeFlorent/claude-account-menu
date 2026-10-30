$langDomainFiles = @(Get-ChildItem -LiteralPath $bin -Filter "*.ps1" | Where-Object { $_.Name -like "claude-sync*" -or $_.Name -like "claude-mcp-*" -or $_.Name -eq "claude-peers.ps1" -or $_.Name -like "claude-menu-prefs*" })
$langDynamic = @("sync.prefs.off.skills", "sync.prefs.off.mcp", "sync.prefs.off.globals", "sync.prefs.erase.skills", "sync.prefs.erase.mcp", "sync.prefs.erase.globals")
$langUsed = New-Object 'System.Collections.Generic.SortedSet[string]' ([StringComparer]::Ordinal)
foreach ($f in $langDomainFiles) {
  foreach ($m in [regex]::Matches([IO.File]::ReadAllText($f.FullName), 'Get-ClmText\s+"((?:sync|mcp)\.[A-Za-z0-9.]+)"')) { [void]$langUsed.Add($m.Groups[1].Value) }
}
foreach ($k in $langDynamic) { [void]$langUsed.Add($k) }
$langEn = ConvertFrom-JsonText ([IO.File]::ReadAllText((Join-Path $bin "lang/en.json"), [Text.Encoding]::UTF8))
$langFr = ConvertFrom-JsonText ([IO.File]::ReadAllText((Join-Path $bin "lang/fr.json"), [Text.Encoding]::UTF8))
function Get-LangSlots {
  param([string]$Text)
  return (@([regex]::Matches($Text, '\{\d\}') | ForEach-Object { $_.Value } | Sort-Object) -join "")
}

$langOwn = @($langEn.Keys | Where-Object { $_ -like "sync.*" -or $_ -like "mcp.*" })

Assert-True ($langUsed.Count -gt 40) "textes de synchro : les cles utilisees sont relevees"
foreach ($k in $langUsed) {
  Assert-True ($null -ne $langEn[$k] -and $langEn[$k] -ne "") ("cle " + $k + " : anglais present")
  Assert-True ($null -ne $langFr[$k] -and $langFr[$k] -ne "") ("cle " + $k + " : francais present")
}
foreach ($k in $langOwn) { Assert-True ($langUsed.Contains($k)) ("cle " + $k + " : utilisee par un fichier de synchro") }
Assert-Equal "" (@($langOwn | Where-Object { $null -eq $langFr[$_] }) -join ",") "textes de synchro : memes cles en francais et en anglais"

$langBadFrench = '\b(reglages?|reglables?|regler|echou\w*|ecriture|definition|creee|enregistre|enregistree|changee|oubliee|arretee|refuse|modifie|chiffre|caracteres|different|decoch\w*|coches|envoyes|derivation|apres|efface|deja|synchronise|cle)\b|\ba (la|ce|sa|une|jour|corriger|supprimer)\b'
$langBadChars = '[\u00A0\u202F\u2009\u200B\uFEFF\u2018\u2019\u201C\u201D\u2014\u00AB\u00BB]'
foreach ($k in $langOwn) {
  $fr = [string]$langFr[$k]
  $en = [string]$langEn[$k]
  Assert-True (-not [regex]::IsMatch($fr, $langBadFrench, "IgnoreCase")) ("cle " + $k + " : francais avec ses accents")
  Assert-True (-not [regex]::IsMatch($en, '[^\x00-\x7F]')) ("cle " + $k + " : anglais sans accent")
  Assert-True (-not [regex]::IsMatch($fr + $en, $langBadChars)) ("cle " + $k + " : ni espace insecable ni guillemet courbe")
  Assert-Equal (Get-LangSlots $en) (Get-LangSlots $fr) ("cle " + $k + " : memes valeurs a remplacer")
}
Assert-True ($langFr["sync.pass.created"].Contains([string][char]0xE9 + [string][char]0xE9)) "textes de synchro : creee prend ses deux accents"
Assert-True ($langFr["sync.prefs.title"].Contains("R" + [char]0xE9 + "glages")) "textes de synchro : Reglages prend son accent"
Assert-True ($langFr["sync.prefs.key.escape"].StartsWith([string][char]0xC9)) "textes de synchro : Echap prend sa majuscule accentuee"

$langKept = [Environment]::GetEnvironmentVariable("CLM_LANG")
try {
  [Environment]::SetEnvironmentVariable("CLM_LANG", "en")
  Assert-Equal $langEn["sync.prefs.erase.skills"] (Get-PrefsEraseWarn "skills").Trim() "web : avertissement d'effacement en anglais"
  Assert-Equal $langEn["sync.prefs.off.mcp"] (Get-PrefsOffWarn "mcp").Trim() "web : avertissement de decochage en anglais"
  Assert-Equal $langEn["sync.prefs.thisPc"] (Get-PrefsThisPc) "web : nom de ce PC en anglais"
  Assert-Equal $langEn["sync.prefs.pc.old"] (Get-PcPrefsSub @{ Pcs = (New-PathMap) } "PC") "web : PC pas a jour en anglais"
  [Environment]::SetEnvironmentVariable("CLM_LANG", "fr")
  Assert-Equal $langFr["sync.prefs.erase.skills"] (Get-PrefsEraseWarn "skills").Trim() "web : avertissement d'effacement en francais"
} finally {
  [Environment]::SetEnvironmentVariable("CLM_LANG", $langKept)
}
