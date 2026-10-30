$webLangKept = $env:CLM_LANG
$env:CLM_LANG = "en"
try {
  $webUsage = [PSCustomObject]@{ Error = $null; Age = 120; Expired = $true; Pct5 = 100; Pct7 = 100; Reset5 = $null; Reset7 = $null; Acc = [PSCustomObject]@{ Label = "a"; Dir = ".claude-web-en" } }
  $webView = Get-UsageView $webUsage
  $webEntry = @{ Acc = $webUsage.Acc; U = $webUsage; Pending = $false; Seen = $true; Force = $false; NextAt = 1000; Slot = 0 }
  $webTexts = @($webView.Badge, $webView.Note, (Get-EntryTimer $webEntry $true 0 0)[0], (Get-EntryTimer $webEntry $false 0 0)[0])
  $webEntry.U = [PSCustomObject]@{ Error = "boom"; Age = $null; LimitedUntil = 0; Pct5 = 1; Pct7 = 2 }
  $webTexts += (Get-EntryTimer $webEntry $false 0 0)[0]
  $webTexts += (Get-ForcedReadMsg $webEntry 0)[0]
  $webEntry.U = [PSCustomObject]@{ Error = $null; Age = 90; LimitedUntil = 0; Pct5 = 1; Pct7 = 2 }
  $webTexts += (Get-ForcedReadMsg $webEntry 0)[0]
  $webEntry.U = [PSCustomObject]@{ Error = $null; Age = $null; LimitedUntil = 5000; Pct5 = 1; Pct7 = 2 }
  $webTexts += (Get-ForcedReadMsg $webEntry 1000)[0]
  $webFrench = 'atteint|fenetre|passee|il y a|reessai|relecture|relus|deja|a jour|maj |pause API|en pause|lecture'
  foreach ($t in $webTexts) {
    Assert-True ([string]$t -cnotmatch $webFrench) ("web en anglais : aucun mot francais dans [" + $t + "]")
    Assert-True ([string]$t -cmatch '^[\x20-\x7E]*$') ("web en anglais : texte ASCII [" + $t + "]")
  }
  Assert-Equal (Get-ClmText "menu.usage.quota_7d_reached" -Lang "en") $webView.Badge "web en anglais : badge quota 7d"
  Assert-True ($webTexts.Count -ge 8) "web en anglais : tous les textes du menu pour la page sont verifies"
} finally {
  if ($null -eq $webLangKept) { Remove-Item Env:CLM_LANG -ErrorAction SilentlyContinue } else { $env:CLM_LANG = $webLangKept }
}
