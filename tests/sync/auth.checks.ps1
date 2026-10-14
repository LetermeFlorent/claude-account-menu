$pk = New-PkcePair
Assert-Equal 43 $pk.Verifier.Length "verifier PKCE de 43 caracteres"
Assert-True ($pk.Verifier -match '^[A-Za-z0-9_-]+$') "verifier en base64url sans ="
Assert-Equal (ConvertTo-Base64Url (Get-Sha256Bytes $pk.Verifier)) $pk.Challenge "challenge = SHA-256 du verifier"
Assert-True ((New-PkcePair).Verifier -ne $pk.Verifier) "verifier different a chaque connexion"

$url = Get-DriveAuthUrl "id.apps" "http://127.0.0.1:5000" "chal" "st"
foreach ($part in @("access_type=offline", "prompt=consent", "code_challenge_method=S256", "code_challenge=chal", "state=st", "redirect_uri=http%3A%2F%2F127.0.0.1%3A5000", "scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fdrive.file")) {
  Assert-True ($url.Contains($part)) ("URL de consentement avec " + $part)
}

$r = ConvertFrom-AuthRequest "GET /?state=st&code=4%2F0Ab-x&scope=a+b HTTP/1.1"
Assert-Equal "4/0Ab-x" $r.Code "code lu et decode"
Assert-Equal "st" $r.State "etat lu"
Assert-Null $r.Error "pas d'erreur"
$r = ConvertFrom-AuthRequest "GET /?error=access_denied&state=st HTTP/1.1"
Assert-Equal "access_denied" $r.Error "refus lu"
$r = ConvertFrom-AuthRequest "GET /favicon.ico HTTP/1.1"
Assert-True (-not $r.Code -and -not $r.Error) "requete sans parametre ignoree"

$script:TokenPosts = @()
function Invoke-DriveTokenPost { param([string]$Body) $script:TokenPosts += $Body; return [PSCustomObject]@{ access_token = "neuf"; expires_in = 3600 } }
$now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
Save-DriveConfig @{ refreshToken = "r1"; clientId = "cid"; clientSecret = "sec"; accessToken = "vieux"; expiresAt = $now + 600000 }
Assert-Equal "vieux" (Get-DriveToken) "jeton encore valable rendu sans appel"
Assert-Equal 0 $script:TokenPosts.Count "aucun appel a Google"
Save-DriveConfig @{ refreshToken = "r1"; clientId = "cid"; clientSecret = "sec"; accessToken = "vieux"; expiresAt = $now + 30000 }
Assert-Equal "neuf" (Get-DriveToken) "jeton presque expire renouvele"
Assert-True ($script:TokenPosts[0].Contains("grant_type=refresh_token") -and $script:TokenPosts[0].Contains("refresh_token=r1") -and $script:TokenPosts[0].Contains("client_secret=sec")) "renouvellement avec le bon formulaire"
Assert-Equal "neuf" (Read-DriveConfig)["accessToken"] "nouveau jeton sauve"
Assert-Equal "r1" (Read-DriveConfig)["refreshToken"] "jeton de renouvellement garde"
Assert-Equal "neuf" (Get-DriveToken) "jeton sauve reutilise"
Assert-Equal 1 $script:TokenPosts.Count "un seul renouvellement"

function Invoke-DriveTokenPost { param([string]$Body) throw "400 invalid_grant Token has been expired or revoked" }
$err = $null
try { $null = Get-DriveToken -Renew } catch { $err = $_.Exception.Message }
Assert-Equal "reconnecter le Drive : clm --drive-login" $err "jeton Google revoque, demande de reconnexion"
Remove-Item -LiteralPath $script:DriveConfigPath -Force
$err = $null
try { $null = Get-DriveToken } catch { $err = $_.Exception.Message }
Assert-Equal "reconnecter le Drive : clm --drive-login" $err "sans config, demande de connexion"
. (Join-Path $bin "claude-drive-login.ps1")
