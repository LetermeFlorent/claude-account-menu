. Import-ClmModule claude-self-copy
$langTarget = Join-Path $script:Sandbox "install-bin"
$null = Install-ClmFiles $bin $langTarget "" @("clm")
$langShipped = @(Get-ChildItem -LiteralPath (Join-Path $bin "lang") -Filter "*.json" | ForEach-Object { "lang/" + $_.Name } | Sort-Object)
$langCopied = @(foreach ($rel in $langShipped) { if (Test-ClmSameFile (Join-Path $bin $rel) ([IO.Path]::Combine($langTarget, $rel))) { $rel } })
$langListed = @([IO.File]::ReadAllLines((Join-Path $langTarget "clm.files")) | Where-Object { $_ -like "lang/*.json" } | Sort-Object)

Assert-Equal "lang/en.json lang/fr.json" ($langShipped -join " ") "installation du vrai dossier bin : fichiers de langue livres"
Assert-Equal ($langShipped -join " ") ($langCopied -join " ") "installation du vrai dossier bin : bin/lang/*.json copies a l'identique"
Assert-Equal ($langShipped -join " ") ($langListed -join " ") "installation du vrai dossier bin : fichiers de langue listes dans clm.files"
Assert-True (-not [IO.File]::Exists((Join-Path $langTarget "clm"))) "installation du vrai dossier bin : lanceur sh ecarte"
