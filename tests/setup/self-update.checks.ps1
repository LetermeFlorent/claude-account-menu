. (Join-Path $PSScriptRoot "self-update-fakes.ps1")

try {
  $published = [DateTimeOffset]::Parse("2026-10-28T08:33:20Z", [Globalization.CultureInfo]::InvariantCulture).ToUnixTimeSeconds()
  $r = ConvertFrom-ReleaseJson (New-TestRelease 40)
  Assert-Equal 40 $r.Number "release GitHub, numero lu dans le tag"
  Assert-Equal $published $r.Time "release GitHub, date de publication"
  Assert-Equal "v40" (Get-ClmName $r) "release GitHub, nom affiche"
  Assert-Null (ConvertFrom-ReleaseJson '{"message":"Not Found"}') "pas de release publiee"
  Assert-Null (ConvertFrom-ReleaseJson ((New-TestRelease 40) -replace '"v40"', '"v40-beta"')) "tag hors format refuse"
  Assert-Null (ConvertFrom-ReleaseJson ((New-TestRelease 40) -replace '"v40"', '"nightly"')) "tag sans numero refuse"

  Set-SelfNetwork "" "" (New-TestRelease 40)
  Assert-Equal 40 (Get-LatestClm).Number "derniere release lue"
  Assert-Equal "https://api.github.com/repos/LetermeFlorent/claude-account-menu/releases/latest 4" ($script:SelfGets -join "|") "derniere release demandee a l'API, quatre secondes"

  $script:SelfInstalled = $null
  Set-SelfNetwork "" "" (New-TestRelease 40)
  Assert-Throws { Find-ClmUpdate } "version de clm inconnue" "version installee inconnue : recherche refusee"
  Assert-Equal 0 $script:SelfGets.Count "version installee inconnue : pas de reseau"
  $out = (Update-Clm 6>&1 | Out-String)
  Assert-True ($out -match "version de clm inconnue" -and $out -match "releases" -and $out -match "False") "version installee inconnue : message et pas de mise a jour"
  $script:SelfInstalled = ConvertFrom-ClmVersion "aaaaaaa1111111111111111111111111111111aa 1760000000"
  Assert-Throws { Find-ClmUpdate } "version de clm inconnue" "version installee sans numero : recherche refusee"

  $script:SelfInstalled = ConvertFrom-ClmVersion "aaaaaaa1111111111111111111111111111111aa 1760000000 34"
  Set-SelfNetwork "" "" (New-TestRelease 40)
  Assert-Equal 40 (Find-ClmUpdate).Number "release plus recente : trouvee"
  Set-SelfNetwork "" "" (New-TestRelease 34)
  Assert-Null (Find-ClmUpdate) "meme version : rien"
  Set-SelfNetwork "" "" (New-TestRelease 30)
  Assert-Null (Find-ClmUpdate) "version installee plus recente que la release : gardee"
  Set-SelfNetwork "" "" $null
  $out = @(Update-Clm 6>&1)
  Assert-Equal "False" ($out -join "|") "reseau coupe : rien affiche, pas de mise a jour"

  $zip = New-TestPackage "clm-v40"
  $hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLower()
  $latest = ConvertFrom-ReleaseJson (New-TestRelease 40)
  $base = "https://github.com/LetermeFlorent/claude-account-menu/releases/download/v40/clm-v40.zip"

  Set-SelfNetwork $zip ("0" * 64 + "  clm-v40.zip`n") (New-TestRelease 40)
  Assert-Throws { Install-ClmVersion $latest } "empreinte" "empreinte differente : installation refusee"
  Assert-Equal 0 $script:SelfRuns.Count "empreinte differente : installeur jamais lance"
  Assert-Equal ($base + ".sha256 10|" + $base + " 60") ($script:SelfGets -join "|") "paquet et empreinte telecharges depuis la release"

  Set-SelfNetwork $zip "pas une empreinte" (New-TestRelease 40)
  Assert-Throws { Install-ClmVersion $latest } "empreinte" "fichier d'empreinte illisible : installation refusee"
  Assert-Equal 0 $script:SelfRuns.Count "fichier d'empreinte illisible : installeur jamais lance"

  Set-SelfNetwork $zip ($hash.ToUpper() + "  clm-v40.zip`n") (New-TestRelease 40)
  Install-ClmVersion $latest
  Assert-Equal 1 $script:SelfRuns.Count "empreinte correcte : installeur lance une fois"
  $run = $script:SelfRuns[0]
  if ($script:OsName -eq "Windows") {
    Assert-Equal ($env:SystemRoot + "\System32\WindowsPowerShell\v1.0\powershell.exe") $run.Exe "Windows : chemin absolu de powershell"
    Assert-Equal "install.ps1" ([IO.Path]::GetFileName($run.Arguments[-1])) "Windows : install.ps1 du paquet"
  } else {
    Assert-Equal "/bin/sh" $run.Exe "hors Windows : chemin absolu de sh"
    Assert-Equal "install.sh" ([IO.Path]::GetFileName($run.Arguments[-1])) "hors Windows : install.sh du paquet"
  }
  Assert-True $run.Found "installeur extrait avant d'etre lance"
  Assert-True (-not (Test-Path -LiteralPath (Split-Path -Parent (Split-Path -Parent $run.Arguments[-1])))) "dossier temporaire efface"

  Set-SelfNetwork $zip ($hash + "  clm-v40.zip`n") (New-TestRelease 40)
  $script:SelfCode = 3
  Assert-Throws { Install-ClmVersion $latest } "installeur en echec : erreur de copie" "installeur en echec : erreur remontee"

  $cmd = Get-ClmInstallerCommand "C:\t\pkg" "Windows"
  Assert-Equal ($env:SystemRoot + "\System32\WindowsPowerShell\v1.0\powershell.exe") $cmd.Exe "commande Windows, interpreteur"
  Assert-Equal "-NoProfile -ExecutionPolicy Bypass -File" (($cmd.Arguments | Select-Object -First 4) -join " ") "commande Windows, options"
  $cmd = Get-ClmInstallerCommand "/t/pkg" "Linux"
  Assert-Equal "/bin/sh" $cmd.Exe "commande Linux, interpreteur"
  Assert-Equal "install.sh" ([IO.Path]::GetFileName($cmd.Arguments[-1])) "commande Linux, script"

  $lockedDir = New-ClmPrivateDir
  try {
    if ($script:OsName -eq "Windows") {
      $acl = Get-Acl -LiteralPath $lockedDir
      $me = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
      $others = @($acl.Access | Where-Object { $_.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value -ne $me })
      Assert-True ($acl.AreAccessRulesProtected -and $others.Count -eq 0) "dossier temporaire reserve a l'utilisateur"
    } else {
      Assert-Equal "drwx------" (Get-Item -LiteralPath $lockedDir).UnixMode "dossier temporaire en 700"
    }
  } finally { Remove-Item -LiteralPath $lockedDir -Recurse -Force -ErrorAction SilentlyContinue }
} finally {
  Restore-SelfFakes
  $script:SelfInstalled = $null
}
