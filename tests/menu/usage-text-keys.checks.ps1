. Import-ClmModule claude-json
$textFiles = @("claude-menu-card.ps1", "claude-menu-usage-line.ps1", "claude-menu-view.ps1", "claude-menu-timer.ps1", "claude-menu-state.ps1")
$textKeys = @()
foreach ($name in $textFiles) {
  $source = [IO.File]::ReadAllText((Join-Path $bin $name))
  foreach ($m in [regex]::Matches($source, 'Get-ClmText "([^"]+)"')) { $textKeys += $m.Groups[1].Value }
}
$textKeys = @($textKeys | Sort-Object -Unique)
Assert-True ($textKeys.Count -ge 19) "textes du menu : les cles des cinq fichiers sont trouvees"
$tables = @{}
foreach ($code in @("en", "fr")) { $tables[$code] = ConvertFrom-JsonText ([IO.File]::ReadAllText((Join-Path (Join-Path $bin "lang") ($code + ".json")), [Text.Encoding]::UTF8)) }
foreach ($key in $textKeys) {
  Assert-True ($null -ne $tables["en"][$key] -and "" -ne $tables["en"][$key]) ("textes du menu : " + $key + " present en anglais")
  Assert-True ($null -ne $tables["fr"][$key] -and "" -ne $tables["fr"][$key]) ("textes du menu : " + $key + " present en francais")
}
$bare = 'reessai|\bdeja\b|demandee|fenetre|passee|relus a |\ba jour'
$stripped = @($textKeys | Where-Object { [string]$tables["fr"][$_] -cmatch $bare })
Assert-Equal "" ($stripped -join " ") "textes du menu : aucun texte francais sans ses accents"
$acute = [string][char]0x00E9
$grave = [string][char]0x00E0
Assert-True ($tables["fr"]["menu.timer.retry"].StartsWith("r" + $acute + "essai")) "textes du menu : reessai accentue"
Assert-True ($tables["fr"]["menu.state.read_in_progress"].Contains("d" + $acute + "j" + $grave)) "textes du menu : deja accentue"
Assert-True ($tables["fr"]["menu.state.reread_requested"].EndsWith("demand" + $acute + "e")) "textes du menu : demandee accentue"
Assert-True ($tables["fr"]["menu.usage.window_passed"].StartsWith("fen" + [char]0x00EA + "tre pass" + $acute + "e")) "textes du menu : fenetre passee accentue"
Assert-True ($tables["fr"]["menu.timer.forced.reread"].Contains("relus " + $grave + " ")) "textes du menu : relus a accentue"
Assert-True ($tables["fr"]["menu.timer.forced.up_to_date"].StartsWith("d" + $acute + "j" + $grave + " " + $grave + " jour")) "textes du menu : deja a jour accentue"
