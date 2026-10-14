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
Assert-Null (Read-DriveConfig) "config illisible lue comme absente"
Remove-Item -LiteralPath $script:DriveConfigPath -Force
