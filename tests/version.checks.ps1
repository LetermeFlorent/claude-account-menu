$old = [PSCustomObject]@{ Sha = "aaaaaaa1111111111111111111111111111111aa"; Time = [long]1760000000 }
$new = [PSCustomObject]@{ Sha = "bbbbbbb2222222222222222222222222222222bb"; Time = [long]1760090000 }

$v = ConvertFrom-ClmVersion ("  " + $new.Sha + " 1760090000`r`n")
Assert-Equal $new.Sha $v.Sha "version lue, commit"
Assert-Equal 1760090000 $v.Time "version lue, date"
Assert-Null (ConvertFrom-ClmVersion "") "version vide refusee"
Assert-Null (ConvertFrom-ClmVersion "main 1760090000") "version sans commit refusee"

$dir = Join-Path $script:Sandbox "version-bin"
New-Item -ItemType Directory -Path $dir | Out-Null
Assert-Null (Read-ClmVersion $dir) "pas de fichier de version"
Write-ClmVersion $new $dir
Assert-Equal ($new.Sha + " " + $new.Time) ((Read-ClmVersion $dir).Sha + " " + (Read-ClmVersion $dir).Time) "version ecrite puis relue"
Assert-True ((Format-ClmVersion $new) -match "^bbbbbbb du \d\d/\d\d/\d{4} \d\d:\d\d$") "version affichee"
Assert-Equal "inconnue" (Format-ClmVersion $null) "version inconnue affichee"

Assert-True (Test-ClmOutdated $old $new) "commit plus recent sur GitHub : mise a jour"
Assert-True (Test-ClmOutdated $null $new) "version installee inconnue : mise a jour"
Assert-Equal $false (Test-ClmOutdated $new $new) "meme commit : rien"
Assert-Equal $false (Test-ClmOutdated $new $old) "installe plus recent que GitHub : rien"
Assert-Equal $false (Test-ClmOutdated $old $null) "GitHub injoignable : rien"

Assert-Null (Get-BackupVersionError $new $null) "sauvegarde sans version : acceptee"
Assert-Null (Get-BackupVersionError $new $new) "sauvegarde de la meme version : acceptee"
Assert-Null (Get-BackupVersionError $new $old) "sauvegarde plus ancienne : acceptee"
Assert-True ((Get-BackupVersionError $old $new) -match "^sauvegarde faite avec clm bbbbbbb .*plus recent que clm aaaaaaa .*relance clm") "sauvegarde plus recente : refusee"
Assert-True ((Get-BackupVersionError $null $new) -match "version installee inconnue") "version installee inconnue : refusee"

$json = '{"sha":"' + $new.Sha + '","node_id":"x","commit":{"author":{"name":"a","date":"2026-10-12T08:00:00Z"},"committer":{"name":"F","email":"f@x","date":"2025-10-10T08:33:20Z"},"message":"m"},"committer":{"login":"F"}}'
$c = ConvertFrom-CommitJson $json
Assert-Equal $new.Sha $c.Sha "commit GitHub, sha"
Assert-Equal 1760085200 $c.Time "commit GitHub, date du committer"
Assert-Null (ConvertFrom-CommitJson '{"message":"API rate limit exceeded"}') "reponse GitHub sans commit"

Initialize-Tar
$src = Join-Path $script:Sandbox "version-home"
New-Item -ItemType Directory -Path (Join-Path $src ".local/bin") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $src ".claude") -Force | Out-Null
Write-ClmVersion $new (Join-Path $src ".local/bin")
$ext = Get-ArchiveExtension $script:TarFlavor
$withVersion = Join-Path $script:Sandbox ("avec-version" + $ext)
$withoutVersion = Join-Path $script:Sandbox ("sans-version" + $ext)
& $script:Tar -a -c -f $withVersion -C $src ".claude" ".local/bin/clm.version"
& $script:Tar -a -c -f $withoutVersion -C $src ".claude"
Assert-Equal $new.Sha (Get-BackupVersion $withVersion).Sha "version lue dans la sauvegarde"
Assert-Null (Get-BackupVersion $withoutVersion) "sauvegarde d'avant les versions"
