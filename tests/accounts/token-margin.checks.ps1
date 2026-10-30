$marginNow = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$marginRefreshed = 0
$marginReal = ${function:Update-AccountToken}
function Update-AccountToken {
  param($Acc, $Cred)
  $script:marginRefreshed++
  return [PSCustomObject]@{ claudeAiOauth = [PSCustomObject]@{ accessToken = "renouvele"; expiresAt = $script:marginNow + 3600000 } }
}

$nearEnd = [PSCustomObject]@{ claudeAiOauth = [PSCustomObject]@{ accessToken = "vieux"; expiresAt = $marginNow + 30000 } }
$tok = Get-UsageToken $null $nearEnd
Assert-Equal "renouvele" $tok.Token "jeton qui expire dans 30 s : renouvele avant l'appel"
Assert-Equal 1 $marginRefreshed "jeton qui expire dans 30 s : un renouvellement"

$marginRefreshed = 0
$comfortable = [PSCustomObject]@{ claudeAiOauth = [PSCustomObject]@{ accessToken = "bon"; expiresAt = $marginNow + 120000 } }
Assert-Equal "bon" (Get-UsageToken $null $comfortable).Token "jeton qui expire dans 120 s : garde"
Assert-Equal 0 $marginRefreshed "jeton qui expire dans 120 s : pas de renouvellement"

$expired = [PSCustomObject]@{ claudeAiOauth = [PSCustomObject]@{ accessToken = "mort"; expiresAt = 1000 } }
$tok = Get-UsageToken $null $expired -NoRefresh
Assert-Equal "jeton expire, lancer le compte une fois" $tok.Error "lecture seule : jeton expire signale"
Assert-Equal 0 $marginRefreshed "lecture seule : aucun renouvellement"
$tok = Get-UsageToken $null $nearEnd -NoRefresh
Assert-Equal "vieux" $tok.Token "lecture seule : jeton encore bon pour l'instant garde"
Assert-Equal 0 $marginRefreshed "lecture seule : jeton proche de la fin, pas de renouvellement"

Set-Item Function:\Update-AccountToken $marginReal
$ownerAcc = [PSCustomObject]@{ Label = "sansmail"; Dir = ".claude-sansmail" }
$null = New-Item -ItemType Directory -Path (Join-Path $script:HomeDir ".claude-sansmail") -Force
$remoteOwned = @{ Id = "c9"; Exp = 5; Props = @{ who = "b@y.fr" } }
Assert-Throws { Assert-CredentialOwner $ownerAcc $remoteOwned } (Get-ClmText "drive.cred.unknownOwner") "adresse locale vide : jeton du Drive refuse"
Assert-Equal $null (Assert-CredentialOwner $ownerAcc @{ Id = "c9"; Exp = 5; Props = @{} }) "jeton du Drive sans adresse : pas de controle"
Assert-Equal $null (Assert-CredentialOwner $ownerAcc $null) "pas de jeton distant : pas de controle"

$saveAcc = [PSCustomObject]@{ Label = "save"; Dir = ".claude-savecred" }
$savePath = Join-Path (Join-Path $script:HomeDir ".claude-savecred") ".credentials.json"
$null = New-Item -ItemType Directory -Path (Split-Path -Parent $savePath) -Force
$saveCred = [PSCustomObject]@{ claudeAiOauth = [PSCustomObject]@{ accessToken = "nouveau"; refreshToken = "r"; expiresAt = 5 } }
Save-RefreshedCredential $saveAcc $saveCred
Assert-Equal "nouveau" ((Get-Content -LiteralPath $savePath -Raw | ConvertFrom-Json).claudeAiOauth.accessToken) "jeton renouvele : ecrit"
$saveHeld = Open-MachineLock "drive-creds"
$saveWait = $script:CredLockWaitMs
$script:CredLockWaitMs = 200
$saveCred.claudeAiOauth.accessToken = "concurrent"
try { Assert-Throws { Save-RefreshedCredential $saveAcc $saveCred } "jetons en cours de synchro" "jeton renouvele : ecriture attend le verrou des jetons" }
finally { Close-MachineLock $saveHeld; $script:CredLockWaitMs = $saveWait }
Assert-Equal "nouveau" ((Get-Content -LiteralPath $savePath -Raw | ConvertFrom-Json).claudeAiOauth.accessToken) "jeton renouvele : fichier intact pendant le verrou"
Remove-Item -LiteralPath (Split-Path -Parent $savePath) -Recurse -Force
