$regSaved = $null
if (Test-Path -LiteralPath $script:RegistryPath) { $regSaved = [IO.File]::ReadAllBytes($script:RegistryPath) }
$regDir = Split-Path -Parent $script:RegistryPath
function Get-RegistryBadFiles { return @(Get-ChildItem -LiteralPath $regDir -Filter "accounts.json.bad*" -ErrorAction SilentlyContinue) }
function Clear-RegistryFiles { Get-ChildItem -LiteralPath $regDir -Filter "accounts.json*" -ErrorAction SilentlyContinue | Remove-Item -Force }

Clear-RegistryFiles
$accs = @(Get-Accounts)
Assert-Equal "compte1" $accs[0].Label "registre absent : comptes par defaut"
Assert-True (Test-Path -LiteralPath $script:RegistryPath) "registre absent : liste ecrite"

$corrupt = "{ pas du json"
[IO.File]::WriteAllText($script:RegistryPath, $corrupt)
$accs = @(Get-Accounts)
Assert-Equal "compte1" $accs[0].Label "registre illisible : comptes par defaut en memoire"
Assert-Equal $corrupt ([IO.File]::ReadAllText($script:RegistryPath)) "registre illisible : fichier pas reecrit"
$bad = @(Get-RegistryBadFiles)
Assert-Equal 1 $bad.Count "registre illisible : une copie datee gardee"
if ($bad.Count -eq 1) {
  Assert-True ($bad[0].Name -match '^accounts\.json\.bad-\d{8}-\d{6}') "registre illisible : copie datee, nom"
  Assert-Equal $corrupt ([IO.File]::ReadAllText($bad[0].FullName)) "registre illisible : copie fidele"
}
$null = Get-Accounts
Assert-Equal 1 (Get-RegistryBadFiles).Count "registre illisible : pas de copie en double a chaque lecture"

Assert-Throws { Save-Registry @([PSCustomObject]@{ Label = "x"; Dir = ".claude-x" }) } (Get-ClmText "accounts.registry.unreadable") "registre illisible : ecriture refusee"
Assert-Equal $corrupt ([IO.File]::ReadAllText($script:RegistryPath)) "registre illisible : fichier intact apres refus"

Remove-Item -LiteralPath $script:RegistryPath -Force
Clear-RegistryFiles
foreach ($shape in @("", "[1,2]", '{"a":1}', '[{"Label":"x"}]')) {
  [IO.File]::WriteAllText($script:RegistryPath, $shape)
  $null = Get-Accounts
  Assert-Equal $shape ([IO.File]::ReadAllText($script:RegistryPath)) ("registre de mauvaise forme '" + $shape + "' : fichier intact")
  Assert-True ((Get-RegistryBadFiles).Count -ge 1) ("registre de mauvaise forme '" + $shape + "' : copie gardee")
  Clear-RegistryFiles
}

Save-Registry @([PSCustomObject]@{ Label = "a"; Dir = ".claude" }, [PSCustomObject]@{ Label = "b"; Dir = ".claude-b" })
Assert-Equal "a|b" ((@(Get-Accounts) | ForEach-Object { $_.Label }) -join "|") "registre valide : relu"
Assert-Equal 0 @(Get-ChildItem -LiteralPath $regDir -Filter "accounts.json.*.tmp").Count "registre : pas de fichier temporaire laisse"
$lockFs = Enter-FileLock ($script:RegistryPath + ".lock") 1000
$script:RegistryLockWaitMs = 300
Assert-Throws { Save-Registry @([PSCustomObject]@{ Label = "z"; Dir = ".claude" }) } (Get-ClmText "accounts.registry.busy") "registre verrouille : ecriture refusee"
$lockFs.Dispose()
Assert-Equal "a|b" ((@(Get-Accounts) | ForEach-Object { $_.Label }) -join "|") "registre verrouille : contenu intact"

Clear-RegistryFiles
Remove-Item Function:\Get-RegistryBadFiles, Function:\Clear-RegistryFiles
if ($null -ne $regSaved) { [IO.File]::WriteAllBytes($script:RegistryPath, $regSaved) }
