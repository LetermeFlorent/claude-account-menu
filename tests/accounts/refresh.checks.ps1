$cred = '{"claudeAiOauth":{"accessToken":"ancien","refreshToken":"r1","expiresAt":1000,"scopes":["user:inference","user:profile"],"subscriptionType":"max"},"organizationUuid":"org"}' | ConvertFrom-Json
$resp = [PSCustomObject]@{ access_token = "neuf"; refresh_token = "r2"; expires_in = 3600 }
$new = ConvertTo-RefreshedCredential $cred $resp 5000
Assert-Equal "neuf" $new.claudeAiOauth.accessToken "jeton renouvele"
Assert-Equal "r2" $new.claudeAiOauth.refreshToken "refresh token tourne"
Assert-Equal 3605000 $new.claudeAiOauth.expiresAt "expiration recalculee"
Assert-Equal "max" $new.claudeAiOauth.subscriptionType "autres champs gardes"

$path = New-SandboxFile ".claude-refresh/.credentials.json" "{}"
Write-CredentialFile $path $new
$back = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
Assert-Equal "neuf" $back.claudeAiOauth.accessToken "fichier reecrit"
Assert-Equal "user:inference user:profile" (@($back.claudeAiOauth.scopes) -join " ") "scopes gardes dans le fichier"
Assert-Equal "org" $back.organizationUuid "champ racine garde dans le fichier"
Assert-Equal 0 @(Get-ChildItem -LiteralPath (Split-Path $path) -Filter "*.tmp").Count "pas de fichier temporaire laisse"

$os = $script:OsName
$script:OsName = "MacOS"
Assert-Null (Update-AccountToken ([PSCustomObject]@{ Label = "x"; Dir = ".claude-refresh" }) $cred) "pas de renouvellement sous macOS"
$script:OsName = $os

$same = ConvertTo-RefreshedCredential $cred ([PSCustomObject]@{ access_token = "x"; expires_in = 60 }) 0
Assert-Equal "r2" $same.claudeAiOauth.refreshToken "refresh token garde sans rotation"
Assert-True ((Get-OauthUserAgent) -match "^claude-cli/\d+\.\d+\.\d+ \(external, cli\)$") "renouvellement presente comme Claude Code"

Assert-Equal "non connecte" (Get-UsageToken $null $null).Error "jeton absent"
$future = [DateTimeOffset]::UtcNow.AddHours(1).ToUnixTimeMilliseconds()
$live = [PSCustomObject]@{ claudeAiOauth = [PSCustomObject]@{ accessToken = "tok"; expiresAt = $future } }
Assert-Equal "tok" (Get-UsageToken $null $live).Token "jeton valide garde"
$realRefresh = ${function:Update-AccountToken}
Set-Item Function:\Update-AccountToken { param($Acc, $Cred) return $null }
$live.claudeAiOauth.expiresAt = 1
Assert-Equal "compte deconnecte, lancer le compte une fois" (Get-UsageToken $null $live).Error "renouvellement en echec"
Set-Item Function:\Update-AccountToken $realRefresh
Assert-Equal "API de suivi injoignable" (Get-UsageErrorText $null) "sans reponse HTTP"
Assert-Equal "jeton refuse, lancer le compte une fois" (Get-UsageErrorText ([PSCustomObject]@{ StatusCode = 401 })) "jeton refuse par l'API"
