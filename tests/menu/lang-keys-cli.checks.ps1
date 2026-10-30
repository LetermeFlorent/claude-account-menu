. (Join-Path $bin "claude-text.ps1")
$langFiles = @("claude-menu.ps1", "claude-menu-loop.ps1", "claude-menu-fails.ps1")
$langKeys = @(foreach ($f in $langFiles) {
  foreach ($m in [regex]::Matches([IO.File]::ReadAllText((Join-Path $bin $f)), 'Get-ClmText "([^"]+)"')) { $m.Groups[1].Value }
}) | Sort-Object -Unique
$langEn = Read-ClmTextTable (Join-Path $bin "lang\en.json")
$langFr = Read-ClmTextTable (Join-Path $bin "lang\fr.json")
Assert-True ($langKeys.Count -ge 14) "menu : les cles du menu sont relevees dans les sources"
foreach ($k in $langKeys) {
  Assert-True ($langEn.Contains($k) -and $langFr.Contains($k)) ("menu : cle " + $k + " dans les deux langues")
}
$langAccents = @{ "menu.cli.clm.updated.restarting" = @(233, 224); "menu.loop.fail.prefs" = @(233); "menu.loop.no.clm.update" = @(224) }
foreach ($k in $langAccents.Keys) {
  foreach ($code in $langAccents[$k]) {
    Assert-True ($langFr[$k].Contains([string][char]$code)) ("menu : " + $k + " garde ses accents en francais")
  }
}
Assert-True (-not ($langFr[$langKeys[0]] -match "[\u00A0\u202F\u2019\u00AB\u00BB]")) "menu : francais sans espace insecable ni guillemet courbe"
