. (Join-Path $bin "core/claude-text.ps1")

$keyFiles = @()
foreach ($pattern in @("claude-ui-*.ps1", "claude-usage*.ps1", "claude-web-*.ps1", "claude-statusline-seed.ps1", "claude-seed-hook.ps1", "claude-token-refresh.ps1", "claude-display.ps1", "claude-theme.ps1", "claude-color.ps1", "claude-menu-web.ps1")) {
  $keyFiles += @(Get-ChildItem -LiteralPath $bin -Filter $pattern -Recurse)
}
$keyFiles = @($keyFiles | Sort-Object FullName -Unique)
$keyTables = @{}
foreach ($code in @("en", "fr")) { $keyTables[$code] = ConvertFrom-JsonText ([IO.File]::ReadAllText((Join-Path $bin ("lang\" + $code + ".json")), [Text.Encoding]::UTF8)) }

$keyUsed = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($f in $keyFiles) {
  $text = [IO.File]::ReadAllText($f.FullName)
  foreach ($m in [regex]::Matches($text, 'Get-ClmText\s+"([^"$]+)"')) { [void]$keyUsed.Add($m.Groups[1].Value) }
  foreach ($m in [regex]::Matches($text, '=\s*"((?:ui|web|usage)\.[A-Za-z.]+)"')) { [void]$keyUsed.Add($m.Groups[1].Value) }
}
Assert-True ($keyUsed.Count -gt 30) "textes : les fichiers de l'interface et de la page web utilisent des cles"
foreach ($k in $keyUsed) {
  Assert-True ($keyTables["en"].ContainsKey($k)) ("textes : " + $k + " existe en anglais")
  Assert-True ($keyTables["fr"].ContainsKey($k)) ("textes : " + $k + " existe en francais")
}

$accented = [ordered]@{
  "ui.footer.settings" = 'r\u00e9glages'; "ui.pace.epuise" = '\u00e9puis\u00e9'; "ui.pace.debut" = 'd\u00e9but'
  "ui.reset.past" = 'pass\u00e9'; "ui.stale.expired" = 'fen\u00eatre pass\u00e9e'; "ui.usage.signedOut" = 'd\u00e9connect\u00e9'
  "ui.usage.tokenExpired" = 'expir\u00e9'; "ui.usage.tokenRefused" = 'refus\u00e9'; "ui.usage.notSignedIn" = 'connect\u00e9'
  "ui.usage.busy" = 'occup\u00e9e'; "ui.usage.limited" = 'r\u00e9essai'; "ui.display.badKey" = 'r\u00e9glage'
  "ui.display.badWebTheme" = 'th\u00e8me'; "ui.poll.refused" = 'd\u00e9lai'; "ui.progress.stopping" = 'arr\u00eat demand\u00e9'
}
foreach ($k in $accented.Keys) {
  Assert-True ($keyTables["fr"][$k].Contains([regex]::Unescape($accented[$k]))) ("textes : " + $k + " garde ses accents")
}

$nonAscii = New-Object regex '[^\u0000-\u007F]'
$sameInBoth = @("ui.footer.sync", "ui.pace.normal")
foreach ($k in $keyTables["en"].Keys) {
  if (-not ($k.StartsWith("ui.") -or $k.StartsWith("web.job.") -or $k.StartsWith("web.menu.") -or $k.StartsWith("web.thisPc"))) { continue }
  Assert-True (-not $nonAscii.IsMatch([string]$keyTables["en"][$k])) ("textes : " + $k + " sans accent en anglais")
  if ($sameInBoth -notcontains $k) { Assert-True ($keyTables["en"][$k] -cne $keyTables["fr"][$k]) ("textes : " + $k + " traduit") }
  Assert-True (-not ([string]$keyTables["fr"][$k]).Contains([string][char]0x00A0)) ("textes : " + $k + " sans espace insecable")
}

$webKeys = @($keyUsed | Where-Object { $_.StartsWith("ui.") -or $_.StartsWith("web.") -or $_.StartsWith("server.") })
foreach ($k in $webKeys) {
  $en = Get-ClmText $k @("x", "y", "z") "en"
  Assert-True ($en -cne $k -and -not $nonAscii.IsMatch($en)) ("page web en anglais : " + $k)
}
