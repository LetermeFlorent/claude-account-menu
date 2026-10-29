. (Join-Path $bin "claude-text.ps1")

$ulRoot = Split-Path -Parent $bin
$ulNames = @("claude-backup-*.ps1", "claude-menu-restore.ps1", "claude-menu-save.ps1", "claude-menu-archive.ps1", "claude-menu-clm-check.ps1", "claude-menu-startup-clm.ps1", "claude-menu-startup-claude.ps1", "claude-self-*.ps1", "claude-update*.ps1")
$ulFiles = @(foreach ($n in $ulNames) { Get-ChildItem -LiteralPath $bin -Filter $n -File | ForEach-Object { $_.FullName } })
$ulFiles += @((Join-Path $ulRoot "install.ps1"), (Join-Path $ulRoot "install-hook.ps1"))
$ulShell = @((Join-Path $ulRoot "install.sh"), (Join-Path $bin "clm"), (Join-Path $bin "clm-text.sh"))
$ulKeys = New-Object Collections.Generic.List[string]
foreach ($f in $ulFiles) {
  foreach ($m in [regex]::Matches([IO.File]::ReadAllText($f), 'Get-ClmText\s+"([^"]+)"')) { $ulKeys.Add($m.Groups[1].Value) }
}
foreach ($f in $ulShell) {
  if (-not [IO.File]::Exists($f)) { continue }
  foreach ($m in [regex]::Matches([IO.File]::ReadAllText($f), 'clm_text\s+"?([a-zA-Z]+\.[A-Za-z0-9.]+)"?')) { $ulKeys.Add($m.Groups[1].Value) }
}
$ulKeys = @($ulKeys | Sort-Object -Unique)
Assert-True ($ulKeys.Count -gt 40) "textes de mise a jour : cles trouvees dans les fichiers"

$ulTables = @{}
foreach ($code in @("en", "fr")) { $ulTables[$code] = ConvertFrom-JsonText ([IO.File]::ReadAllText((Join-Path (Join-Path $bin "lang") ($code + ".json")), [Text.Encoding]::UTF8)) }
foreach ($code in @("en", "fr")) {
  $absent = @($ulKeys | Where-Object { $null -eq $ulTables[$code][$_] })
  Assert-Equal "" ($absent -join " ") ("textes de mise a jour : toutes les cles existent en " + $code)
}

$ulOwned = @($ulTables["en"].Keys | Where-Object { $_ -match '^(update|backup|install)\.' } | Sort-Object)
$ulUnused = @($ulOwned | Where-Object { $ulKeys -notcontains $_ })
Assert-Equal "" ($ulUnused -join " ") "textes de mise a jour : aucune cle inutilisee"

$ulFrench = @("sauvegarde", "restaure", "reglage", "telecharg", "mise a jour", "a jour", "creee", "etat ", "reessay", "efface", "installee", "redemarrage", "laissee", "precedent", "termine", "cle ", "avertissement", "introuvable", "attente")
$ulAccentless = @(foreach ($k in $ulOwned) {
  $v = [string]$ulTables["fr"][$k]
  foreach ($w in @("efface", "reglages", "Telechargements", "creee", "etat", "reessayer", "restauree", "installee", "redemarrage", "laissee", "precedent", "telechargement", "terminee", "refusee", "a jour", "mise a jour", "recherche impossible", "echec", "ferme", "connexion utilisee", "verifier")) {
    if ($v -cmatch ("(?i)\b" + [regex]::Escape($w) + "\b")) { $k + ":" + $w }
  }
})
Assert-Equal "" ($ulAccentless -join " ") "textes de mise a jour : aucun mot francais sans ses accents"

$ulEnglish = @(foreach ($k in $ulOwned) {
  $v = [string]$ulTables["en"][$k]
  if ($v -match '[^\x20-\x7E]') { $k + ":non-ascii" }
  foreach ($w in $ulFrench) { if ($v -match ("(?i)\b" + [regex]::Escape($w))) { $k + ":" + $w } }
})
Assert-Equal "" ($ulEnglish -join " ") "textes de mise a jour : l'anglais ne garde aucun mot francais"

$ulHole = { param([string]$Text) return (@([regex]::Matches($Text, '\{[0-9]\}') | ForEach-Object { $_.Value } | Sort-Object) -join "") }
$ulHoles = @($ulOwned | Where-Object { (& $ulHole $ulTables["en"][$_]) -ne (& $ulHole $ulTables["fr"][$_]) })
Assert-Equal "" ($ulHoles -join " ") "textes de mise a jour : memes valeurs a placer dans les deux langues"

$ulSame = @($ulOwned | Where-Object { $ulTables["en"][$_] -ceq $ulTables["fr"][$_] -and $ulTables["en"][$_] -match '[a-z]{4,}' })
Assert-True ($ulSame.Count -le 3) ("textes de mise a jour : les deux langues different (" + ($ulSame -join " ") + ")")
