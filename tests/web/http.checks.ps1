. (Join-Path $PSScriptRoot "http-client.ps1")

try {
  $web = Start-WebServer @{ state = { @{ ok = $true; n = 3 } }; boom = { throw "panne" } }
  Assert-True ($web.Port -gt 0) "web : port choisi par le systeme"
  Assert-True ((Get-WebUrl) -cmatch '^http://127\.0\.0\.1:[0-9]+/\?t=[0-9a-f]{48}$') "web : adresse locale avec jeton"
  Assert-True ($web.Listener.LocalEndpoint.Address.Equals([Net.IPAddress]::Loopback)) "web : ecoute sur 127.0.0.1 seulement"
  $tok = "X-Clm-Token: " + $web.Token
  $json = "Content-Type: application/json"
  $act = '{"do":"rename","acc":".claude","name":"Pro"}'

  $r = Invoke-WebTest (New-WebAsk "GET /")
  Assert-Equal "200" (Get-WebCode $r) "web : page d'accueil"
  Assert-True ($r -match "Content-Type: text/html") "web : page en html"
  Assert-True ($r -match "Content-Security-Policy: default-src 'self'") "web : scripts d'ailleurs refuses"
  Assert-True ($r -match "Cache-Control: no-store") "web : rien en cache"
  Assert-True ($r.EndsWith("<p>clm</p>")) "web : contenu de la page"
  $r = Invoke-WebTest (New-WebAsk "GET /style.css?v=2")
  Assert-True ((Get-WebCode $r) -eq "200" -and $r -match "Content-Type: text/css") "web : feuille de style"
  foreach ($p in @("/secret.txt", "/../claude-menu.ps1", "/clm-web/index.html", "/%2e%2e/claude-menu.ps1", "/api")) {
    Assert-Equal "404" (Get-WebCode (Invoke-WebTest (New-WebAsk ("GET " + $p)))) ("web : " + $p + " hors de la liste")
  }
  foreach ($h in @("evil.com", ("localhost:" + $web.Port), "127.0.0.1")) {
    Assert-Equal "403" (Get-WebCode (Invoke-WebTest (New-WebAsk "GET /" @() "" $h))) ("web : hote " + $h + " refuse")
  }

  Assert-Equal "403" (Get-WebCode (Invoke-WebTest (New-WebAsk "GET /api/state"))) "web : donnees sans jeton refusees"
  Assert-Equal "403" (Get-WebCode (Invoke-WebTest (New-WebAsk "GET /api/state" @("X-Clm-Token: faux")))) "web : mauvais jeton refuse"
  $r = Invoke-WebTest (New-WebAsk "GET /api/state" @($tok))
  Assert-True ((Get-WebCode $r) -eq "200" -and $r -match '"n": 3') "web : donnees avec le jeton"
  $r = Invoke-WebTest (New-WebAsk "GET /api/boom" @($tok))
  Assert-True ((Get-WebCode $r) -eq "500" -and $r -match "panne") "web : erreur de lecture renvoyee"
  Assert-Equal "404" (Get-WebCode (Invoke-WebTest (New-WebAsk "GET /api/rien" @($tok)))) "web : donnee inconnue"
  Assert-Equal "403" (Get-WebCode (Invoke-WebTest (New-WebAsk "GET /api/state" @($tok, "Sec-Fetch-Site: cross-site")))) "web : appel d'un autre site refuse"
  Assert-Equal "403" (Get-WebCode (Invoke-WebTest (New-WebAsk "POST /api/action" @($tok, $json, "Origin: http://evil.com") $act))) "web : action d'une autre origine refusee"
  Assert-Equal "403" (Get-WebCode (Invoke-WebTest (New-WebAsk "OPTIONS /api/action" @("Origin: http://evil.com")))) "web : pre-verification d'un autre site refusee"
  Assert-Equal "415" (Get-WebCode (Invoke-WebTest (New-WebAsk "POST /api/action" @($tok, "Content-Type: text/plain") $act))) "web : action hors json refusee"
  Assert-Equal "400" (Get-WebCode (Invoke-WebTest (New-WebAsk "POST /api/action" @($tok, $json) "{pas du json"))) "web : action illisible"
  Assert-Equal "400" (Get-WebCode (Invoke-WebTest (New-WebAsk "POST /api/action" @($tok, $json) "[1,2]"))) "web : action sans objet"
  Assert-Equal "409" (Get-WebCode (Invoke-WebTest (New-WebAsk "POST /api/action" @($tok, $json) $act))) "web : action refusee hors du menu"
  Assert-Equal "405" (Get-WebCode (Invoke-WebTest (New-WebAsk "PUT /"))) "web : methode inconnue"
  Assert-Equal "405" (Get-WebCode (Invoke-WebTest (New-WebAsk "POST /api/state" @($tok, $json) $act))) "web : ecriture sur une donnee refusee"

  Assert-Equal "400" (Get-WebCode (Invoke-WebTest "BONJOUR`r`n`r`n")) "web : requete illisible"
  Assert-Equal "400" (Get-WebCode (Invoke-WebTest (New-WebAsk "GET /" @("Host: evil.com")))) "web : hote en double refuse"
  Assert-Equal "400" (Get-WebCode (Invoke-WebTest (New-WebAsk "POST /api/action" @($tok, $json, "Transfer-Encoding: chunked")))) "web : envoi par morceaux refuse"
  Assert-Equal "400" (Get-WebCode (Invoke-WebTest (New-WebAsk "POST /api/action" @($tok, $json, "Content-Length: abc")))) "web : taille illisible"
  Assert-Equal "413" (Get-WebCode (Invoke-WebTest (New-WebAsk "POST /api/action" @($tok, $json, "Content-Length: 70000")))) "web : corps trop gros"
  Assert-Equal "400" (Get-WebCode (Invoke-WebTest ("GET / HTTP/1.1`r`nX-Long: " + ("a" * 9000)))) "web : en-tete trop long"
} finally { Restore-WebTestRoot }
