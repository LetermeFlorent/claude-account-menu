. (Join-Path $bin "drive/core/claude-drive-creds.ps1")
$edgeNow = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$edgeRefreshed = 0
$edgeReal = ${function:Update-AccountToken}
function Update-AccountToken {
  param($Acc, $Cred)
  $script:edgeRefreshed++
  return [PSCustomObject]@{ claudeAiOauth = [PSCustomObject]@{ accessToken = "renouvele"; expiresAt = $script:edgeNow + 3600000 } }
}
function New-EdgeCred {
  param($Exp)
  return [PSCustomObject]@{ claudeAiOauth = [PSCustomObject]@{ accessToken = "vieux"; expiresAt = $Exp } }
}

Assert-Equal 60000 $script:CredentialMarginMs "marge : 60 s"
Assert-Equal $script:CredentialMarginMs $script:UsageTokenMarginMs "marge de la lecture du quota : celle des jetons"
try {
  foreach ($edgeCase in @(@(55000, "renouvele", 1), @(65000, "vieux", 0), @(-5000, "renouvele", 1), @(-86400000, "renouvele", 1))) {
    $edgeRefreshed = 0
    $edgeTok = Get-UsageToken $null (New-EdgeCred ($edgeNow + $edgeCase[0]))
    $edgeLabel = "jeton a maintenant " + $edgeCase[0] + " ms : "
    Assert-Equal $edgeCase[1] $edgeTok.Token ($edgeLabel + "jeton rendu")
    Assert-Equal $edgeCase[2] $edgeRefreshed ($edgeLabel + "renouvellements")
  }
  $edgeRefreshed = 0
  Assert-Equal "vieux" (Get-UsageToken $null (New-EdgeCred 0)).Token "jeton expiresAt 0 : garde"
  Assert-Equal 0 $edgeRefreshed "jeton expiresAt 0 : pas de renouvellement"
  $edgeRefreshed = 0
  $edgeMissing = [PSCustomObject]@{ claudeAiOauth = [PSCustomObject]@{ accessToken = "vieux" } }
  Assert-Equal "vieux" (Get-UsageToken $null $edgeMissing).Token "jeton sans expiresAt : garde"
  Assert-Equal 0 $edgeRefreshed "jeton sans expiresAt : pas de renouvellement"
  $edgeRefreshed = 0
  $edgeTok = Get-UsageToken $null (New-EdgeCred 1000) -NoRefresh
  Assert-Equal (Get-ClmText "ui.usage.tokenExpired") $edgeTok.Error "jeton deja expire en lecture seule : signale"
  Assert-Equal 0 $edgeRefreshed "jeton deja expire en lecture seule : pas de renouvellement"
  $edgeTok = Get-UsageToken $null (New-EdgeCred ($edgeNow + 55000)) -NoRefresh
  Assert-Equal "vieux" $edgeTok.Token "jeton dans la marge en lecture seule : garde"
} finally {
  Set-Item Function:\Update-AccountToken $edgeReal
}

foreach ($edgeCase in @(@(55000, $false), @(65000, $true), @(-5000, $false), @(120000, $true))) {
  $edgeUsable = Test-CredentialUsable (New-EdgeCred ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() + $edgeCase[0]))
  Assert-Equal $edgeCase[1] $edgeUsable ("jeton Drive a maintenant " + $edgeCase[0] + " ms : utilisable " + $edgeCase[1])
}
Assert-Equal $false (Test-CredentialUsable (New-EdgeCred 0)) "jeton Drive expiresAt 0 : inutilisable"
Assert-Equal $false (Test-CredentialUsable ([PSCustomObject]@{ claudeAiOauth = [PSCustomObject]@{ accessToken = "x" } })) "jeton Drive sans expiresAt : inutilisable"
Assert-Equal $false (Test-CredentialUsable ([PSCustomObject]@{})) "jeton Drive sans bloc oauth : inutilisable"
Assert-Equal $false (Test-CredentialUsable $null) "jeton Drive absent : inutilisable"
