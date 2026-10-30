. (Join-Path $PSScriptRoot "http-client.ps1")

Assert-True (Test-WebSecret "abc" "abc") "web : jeton identique accepte"
Assert-True (-not (Test-WebSecret "abd" "abc")) "web : jeton different refuse"
Assert-True (-not (Test-WebSecret "abcd" "abc")) "web : jeton plus long refuse"
Assert-True (-not (Test-WebSecret "ab" "abc")) "web : jeton plus court refuse"
Assert-True (-not (Test-WebSecret "" "abc")) "web : jeton vide refuse"
Assert-True (-not (Test-WebSecret $null "abc")) "web : jeton absent refuse"
Assert-True (-not (Test-WebSecret "" "")) "web : aucun jeton attendu, rien accepte"

$auMenu = $script:MenuState
try {
  $auFile = Join-Path $script:Sandbox "secret-web.json"
  $web = Start-WebServer @{ state = { @{ ok = $true; n = 3 } }; boom = { throw ("lecture de " + $auFile + " ratee") }; io = { [IO.File]::ReadAllText($auFile) } }
  $cookie = Get-WebCookieName $web
  $url = New-WebUrl
  Assert-True ($url -cmatch '^http://127\.0\.0\.1:[0-9]+/boot\?c=[0-9a-f]{32}$') "web : adresse avec un code d'entree"
  Assert-True (-not $url.Contains($web.Token)) "web : jeton de session absent de l'adresse"
  $boot = $url.Substring($url.IndexOf("/boot"))
  $r = Invoke-WebTest (New-WebAsk ("GET " + $boot))
  Assert-Equal "303" (Get-WebCode $r) "web : code d'entree accepte, page rechargee"
  Assert-True ($r -cmatch ("(?m)^Set-Cookie: " + $cookie + "=" + $web.Token + "; HttpOnly; SameSite=Strict; Path=/\r$")) "web : jeton pose en cookie protege"
  Assert-True ($r -cmatch '(?m)^Location: /\r$') "web : redirection sans secret dans l'adresse"
  Assert-Equal "403" (Get-WebCode (Invoke-WebTest (New-WebAsk ("GET " + $boot)))) "web : code d'entree a usage unique"

  $url = New-WebUrl
  $boot = $url.Substring($url.IndexOf("/boot"))
  Assert-Equal "403" (Get-WebCode (Invoke-WebTest (New-WebAsk "GET /boot?c=00000000000000000000000000000000"))) "web : mauvais code refuse"
  Assert-Equal "403" (Get-WebCode (Invoke-WebTest (New-WebAsk "GET /boot"))) "web : code absent refuse"
  Assert-Equal "303" (Get-WebCode (Invoke-WebTest (New-WebAsk ("GET " + $boot)))) "web : mauvais essai, le bon code reste valable"
  $url = New-WebUrl
  $web.BootUntil = (Get-NowMs) - 1
  Assert-Equal "403" (Get-WebCode (Invoke-WebTest (New-WebAsk ("GET " + $url.Substring($url.IndexOf("/boot")))))) "web : code expire refuse"
  Assert-Equal 60000 $script:WebBootMs "web : code valable une minute"

  $ok = "Cookie: theme=sombre; " + $cookie + "=" + $web.Token
  Assert-Equal "200" (Get-WebCode (Invoke-WebTest (New-WebAsk "GET /api/state" @($ok)))) "web : donnees avec le cookie"
  Assert-Equal "403" (Get-WebCode (Invoke-WebTest (New-WebAsk "GET /api/state" @("X-Clm-Token: " + $web.Token)))) "web : jeton hors cookie refuse"
  Assert-Equal "403" (Get-WebCode (Invoke-WebTest (New-WebAsk "GET /api/state" @("Cookie: " + $cookie + "=x" + $web.Token)))) "web : cookie avec un autre jeton refuse"
  Assert-Equal "403" (Get-WebCode (Invoke-WebTest (New-WebAsk "GET /api/state" @("Cookie: clm=" + $web.Token)))) "web : cookie d'un autre nom refuse"
  Assert-Equal "403" (Get-WebCode (Invoke-WebTest (New-WebAsk "GET /api/state" @($ok, "Sec-Fetch-Site: cross-site")))) "web : cookie envoye par un autre site refuse"

  $script:MenuState = @{ Msg = @("", $null); Dirty = $false }
  $auHidden = { param([string]$Code) $t = Get-ClmText "server.hiddenError" @($Code); return $t.Substring(0, $t.IndexOf("(" + $Code + ")") + $Code.Length + 2) }
  foreach ($v in @("boom", "io")) {
    $r = Invoke-WebTest (New-WebAsk ("GET /api/" + $v) @($ok))
    Assert-True ((Get-WebCode $r) -eq "500" -and $r.Contains((& $auHidden "W1"))) ("web : erreur de lecture " + $v + " generique avec son code")
    Assert-True (-not $r.Contains("secret-web")) ("web : erreur de lecture " + $v + " sans chemin")
    Assert-True ($script:MenuState.Msg[0].Contains("secret-web") -and $script:MenuState.Msg[0].Contains("W1")) ("web : erreur de lecture " + $v + " detaillee dans le terminal")
  }
  $auErr = $null
  try { throw "le nom perso est deja pris" } catch { $auErr = $_ }
  Assert-Equal "le nom perso est deja pris" (Get-WebErrorText $auErr "W3") "web : message de clm sans chemin garde"
  try { throw ("copie ratee : " + $auFile) } catch { $auErr = $_ }
  Assert-True (-not (Get-WebErrorText $auErr "W3").Contains("secret-web")) "web : message de clm avec un chemin cache"
  try { throw "chemin refuse : .claude/x" } catch { $auErr = $_ }
  Assert-True ((Get-WebErrorText $auErr "W3") -cmatch '\(W3\)') "web : chemin relatif cache aussi"
  try { $null = [IO.File]::ReadAllText($auFile) } catch { $auErr = $_ }
  Assert-True ((Get-WebErrorText $auErr "W3").StartsWith((& $auHidden "W3"))) "web : erreur du systeme toujours generique"
} finally {
  $script:MenuState = $auMenu
  Restore-WebTestRoot
}
