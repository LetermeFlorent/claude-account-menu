$langWebEn = ConvertFrom-JsonText ([IO.File]::ReadAllText((Join-Path (Join-Path $bin "lang") "en.json"), [Text.Encoding]::UTF8))
$langWebKeys = @(
  "accounts.registry.badCopyFailed", "accounts.registry.badDir", "accounts.registry.busy", "accounts.registry.unreadable",
  "accounts.rename.cancelled", "accounts.rename.comma", "accounts.rename.done", "accounts.rename.empty", "accounts.rename.taken", "accounts.rename.unchanged",
  "accounts.move.alreadyAt", "accounts.move.done", "accounts.move.outOfRange", "accounts.move.unknown",
  "accounts.remove.cancelled", "accounts.remove.eraseIncomplete", "accounts.remove.erased", "accounts.remove.impossible", "accounts.remove.last", "accounts.remove.neverErased", "accounts.remove.neverErasedHere", "accounts.remove.removed", "accounts.remove.working",
  "accounts.add.cancelled", "accounts.add.done", "accounts.add.notSignedIn", "accounts.guard.configError", "accounts.link.skipped"
)
$langWebAccents = [regex]("[" + [char]0xC0 + "-" + [char]0xFF + "]")
$langWebWords = @(" compte ", " dossier ", "retire", "efface")
$langWebSavedLang = $env:CLM_LANG
try {
  $env:CLM_LANG = "en"
  foreach ($key in $langWebKeys) {
    $got = Get-ClmText $key
    Assert-Equal ([string]$langWebEn[$key]) $got ("textes web : " + $key + " rendu en anglais")
    Assert-True (-not $langWebAccents.IsMatch($got)) ("textes web : " + $key + " sans accent en anglais")
    $words = @($langWebWords | Where-Object { (" " + $got + " ").Contains($_) })
    Assert-Equal "" ($words -join ",") ("textes web : " + $key + " sans mot francais")
  }
} finally {
  if ($null -eq $langWebSavedLang) { Remove-Item Env:CLM_LANG -ErrorAction SilentlyContinue } else { $env:CLM_LANG = $langWebSavedLang }
}
