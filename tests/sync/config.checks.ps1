Remove-Item -LiteralPath $script:DriveConfigPath -Force -ErrorAction SilentlyContinue
Assert-True (-not (Test-DriveConnected)) "sans fichier, Drive non connecte"
Assert-True (-not (Test-DriveAuto)) "sans fichier, pas de synchro auto"
Assert-Equal ([Environment]::MachineName) (Get-DrivePcName) "nom du PC par defaut"
Save-DriveConfig @{ refreshToken = "r"; clientId = "c" }
Assert-True (Test-DriveConnected) "jeton de renouvellement present, Drive connecte"
Assert-True (Test-DriveAuto) "synchro auto par defaut"
Set-DriveAuto $false
Assert-True (-not (Test-DriveAuto)) "synchro auto coupee"
Assert-Equal "c" (Read-DriveConfig)["clientId"] "reglage garde a l'ecriture"
Set-DriveAuto $true
Assert-True (Test-DriveAuto) "synchro auto remise"
$c = Read-DriveConfig
$c["pc"] = "PC-TEST"
Save-DriveConfig $c
Assert-Equal "PC-TEST" (Get-DrivePcName) "nom du PC force par la config"
[IO.File]::WriteAllText($script:DriveConfigPath, "{ pas du json")
Assert-Throws { Read-DriveConfig } "illisible" "config illisible : lecture en erreur, pas absente"
Assert-True (-not (Test-DriveConnected)) "config illisible : Drive non connecte"
Assert-True (-not (Test-DriveAuto)) "config illisible : pas de synchro auto"
Assert-Equal ([Environment]::MachineName) (Get-DrivePcName) "config illisible : nom du PC par defaut"
Assert-Throws { Set-DriveAuto $false } "illisible" "config illisible : reglage refuse"
Assert-Throws { Get-DriveToken } "illisible" "config illisible : pas de reconnexion proposee"
Assert-Equal "{ pas du json" ([IO.File]::ReadAllText($script:DriveConfigPath)) "config illisible : fichier intact"
[IO.File]::WriteAllText($script:DriveConfigPath, "")
Assert-Throws { Read-DriveConfig } "illisible" "config vide : lecture en erreur"
[IO.File]::WriteAllText($script:DriveConfigPath, "[1, 2]")
Assert-Throws { Read-DriveConfig } "illisible" "config qui n'est pas un objet : lecture en erreur"
Remove-Item -LiteralPath $script:DriveConfigPath -Force
Assert-Null (Read-DriveConfig) "config absente lue comme absente"
