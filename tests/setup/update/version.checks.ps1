$old = [PSCustomObject]@{ Sha = "aaaaaaa1111111111111111111111111111111aa"; Time = [long]1760000000 }
$new = [PSCustomObject]@{ Sha = "bbbbbbb2222222222222222222222222222222bb"; Time = [long]1760090000 }

$v = ConvertFrom-ClmVersion ("  " + $new.Sha + " 1760090000`r`n")
Assert-Equal $new.Sha $v.Sha "version lue, commit"
Assert-Equal 1760090000 $v.Time "version lue, date"
Assert-Null (ConvertFrom-ClmVersion "") "version vide refusee"
Assert-Null (ConvertFrom-ClmVersion "main 1760090000") "version sans commit refusee"

function Write-TestClmVersion {
  param($Version, [string]$Dir)
  $text = $Version.Sha + " " + $Version.Time
  if ([int]$Version.Number -gt 0) { $text += " " + $Version.Number }
  [IO.File]::WriteAllText((Join-Path $Dir "clm.version"), $text + "`n", (New-Object Text.UTF8Encoding $false))
}

$dir = Join-Path $script:Sandbox "version-bin"
New-Item -ItemType Directory -Path $dir | Out-Null
Assert-Null (Read-ClmVersion $dir) "pas de fichier de version"
Write-TestClmVersion $new $dir
Assert-Equal ($new.Sha + " " + $new.Time) ((Read-ClmVersion $dir).Sha + " " + (Read-ClmVersion $dir).Time) "version ecrite puis relue"
Assert-True (((Format-ClmVersion $new) -match '\d\d/\d\d/\d{4} \d\d:\d\d$') -and ((Format-ClmVersion $new) -like (Get-ClmText "update.self.versionAt" @("bbbbbbb", "??/??/???? ??:??")))) "version affichee"
Assert-Equal (Get-ClmText "update.self.versionNone") (Format-ClmVersion $null) "version inconnue affichee"
Assert-Equal (Get-ClmText "update.self.tag" @("bbbbbbb")) (Get-ClmTag $dir) "version courte pour l'en-tete"
Assert-Equal "" (Get-ClmTag (Join-Path $script:Sandbox "absent")) "pas de version, rien dans l'en-tete"

$v34 = ConvertFrom-ClmVersion ($old.Sha + " 1760000000 34")
$v40 = [PSCustomObject]@{ Sha = ""; Time = [long]1760090000; Number = 40 }
Assert-True (Test-ClmOutdated $v34 $v40) "release plus recente : mise a jour"
Assert-Equal $false (Test-ClmOutdated $null $v40) "version installee inconnue : rien"
Assert-Equal $false (Test-ClmOutdated $old $v40) "version installee sans numero : rien"
Assert-Equal $false (Test-ClmOutdated $v34 $v34) "meme numero : rien"
Assert-Equal $false (Test-ClmOutdated $v40 $v34) "installe plus recent que la release : rien"
Assert-Equal $false (Test-ClmOutdated $v34 $null) "GitHub injoignable : rien"
Assert-True (-not (Test-ClmVersionKnown $null) -and -not (Test-ClmVersionKnown $old) -and (Test-ClmVersionKnown $v34)) "version connue seulement avec un numero"

Assert-Null (Get-BackupVersionError $new $null) "sauvegarde sans version : acceptee"
Assert-Null (Get-BackupVersionError $new $new) "sauvegarde de la meme version : acceptee"
Assert-Null (Get-BackupVersionError $new $old) "sauvegarde plus ancienne : acceptee"
Assert-Equal (Get-ClmText "update.self.backupNewer" @((Format-ClmVersion $new), (Format-ClmVersion $old))) (Get-BackupVersionError $old $new) "sauvegarde plus recente : refusee"
Assert-Equal (Get-ClmText "update.self.backupInstalledUnknown" @((Format-ClmVersion $new), "https://github.com/LetermeFlorent/claude-account-menu/releases")) (Get-BackupVersionError $null $new) "version installee inconnue : refusee"


Initialize-Tar
$src = Join-Path $script:Sandbox "version-home"
New-Item -ItemType Directory -Path (Join-Path $src ".local/bin") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $src ".claude") -Force | Out-Null
Write-TestClmVersion $new (Join-Path $src ".local/bin")
$ext = Get-ArchiveExtension $script:TarFlavor
$withVersion = Join-Path $script:Sandbox ("avec-version" + $ext)
$withoutVersion = Join-Path $script:Sandbox ("sans-version" + $ext)
& $script:Tar -a -c -f $withVersion -C $src ".claude" ".local/bin/clm.version"
& $script:Tar -a -c -f $withoutVersion -C $src ".claude"
Assert-Equal $new.Sha (Get-BackupVersion $withVersion).Sha "version lue dans la sauvegarde"
Assert-Null (Get-BackupVersion $withoutVersion) "sauvegarde d'avant les versions"

$testsDir = Join-Path (Split-Path -Parent $bin) "tests"
$commentLines = @(@(Get-ChildItem -LiteralPath $bin -Filter "*.ps1" -Recurse) + @(Get-ChildItem -Path $testsDir -Filter "*.ps1" -Recurse) | Select-String -Pattern '^\s*#' | ForEach-Object { $_.Filename + ":" + $_.LineNumber })
Assert-Equal "" ($commentLines -join ", ") "aucun commentaire dans bin ni tests"
$frenchNames = @(Get-ChildItem -LiteralPath $bin -Filter "*.ps1" -Recurse | Select-String -Pattern 'Get-CompteUsage' | ForEach-Object { $_.Filename + ":" + $_.LineNumber })
Assert-Equal "" ($frenchNames -join ", ") "lecteur de quotas nomme en anglais"

$counted = ConvertFrom-ClmVersion ($new.Sha + " 1760090000 34`n")
Assert-Equal 34 $counted.Number "numero de version lu"
Assert-Equal 0 $v.Number "ancien fichier sans numero"
Write-TestClmVersion $counted $dir
Assert-Equal (Get-ClmText "update.self.tag" @("v34")) (Get-ClmTag $dir) "numero de version dans l'en-tete"
Assert-True ((Format-ClmVersion $counted) -like (Get-ClmText "update.self.versionAt" @("v34", "*"))) "numero de version dans les messages"
