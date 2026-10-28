. (Join-Path $PSScriptRoot "http-client.ps1")

try {
  $web = Start-WebServer @{ state = { @{ ok = $true; n = 3 } } }
  $tok = Get-WebTestCookie
  $json = "Content-Type: application/json"
  $act = '{"do":"rename","acc":".claude","name":"Pro"}'

  $c = Connect-WebTest
  try {
    $ask = New-WebAsk "GET /"
    Send-WebTestBytes $c $ask.Substring(0, 10)
    Assert-Equal "" (Read-WebTestReply $c $false 200) "web : requete coupee en deux, attente de la suite"
    Send-WebTestBytes $c $ask.Substring(10)
    Assert-Equal "200" (Get-WebCode (Read-WebTestReply $c)) "web : requete coupee en deux, reponse a la fin"
  } finally { $c.Close() }

  $c = Connect-WebTest
  try {
    Start-Sleep -Milliseconds 50
    Receive-WebRequests $false
    Assert-Equal 1 $script:Web.Conns.Count "web : connexion muette gardee un moment"
    Receive-WebRequests $false ((Get-NowMs) + $script:WebReadMs + 1000)
    Assert-Equal 0 $script:Web.Conns.Count "web : connexion muette fermee apres le delai"
  } finally { $c.Close() }

  $c = Connect-WebTest
  try {
    Start-Sleep -Milliseconds 50
    Receive-WebRequests $false
    Send-WebTestBytes $c "G"
    Start-Sleep -Milliseconds 50
    Receive-WebRequests $false ((Get-NowMs) + $script:WebReadMs + 1000)
    Assert-Equal 0 $script:Web.Conns.Count "web : un octet de temps en temps ne garde pas la connexion"
  } finally { $c.Close() }

  $c = Connect-WebTest
  try {
    Send-WebTestBytes $c (New-WebAsk "POST /api/action" @($tok, $json) $act)
    $null = Read-WebTestReply $c $true 300
  } finally { $c.Close() }
  Start-Sleep -Milliseconds 50
  Assert-Null (Get-WebAction) "web : action d'un onglet ferme jetee sans etre lancee"

  $webSavedFile = ${function:Send-WebFile}
  try {
    ${function:Send-WebFile} = { throw "lecture ratee" }
    $r = Invoke-WebTest (New-WebAsk "GET /")
    Assert-True ((Get-WebCode $r) -eq "500" -and $r -match "W2" -and $r -notmatch "lecture ratee") "web : erreur imprevue rendue en 500 sans detail, le menu continue"
  } finally { ${function:Send-WebFile} = $webSavedFile }

  $c = Connect-WebTest
  try {
    Send-WebTestBytes $c (New-WebAsk "POST /api/action" @($tok, ($json + "; charset=utf-8")) $act)
    Assert-Equal "" (Read-WebTestReply $c $true 300) "web : action gardee jusqu'a sa reponse"
    $item = Get-WebAction
    Assert-Equal "rename Pro" ("" + $item.Args["do"] + " " + $item.Args["name"]) "web : action lue"
    Assert-Null (Get-WebAction) "web : file d'actions videe"
    Send-WebJson $item.Conn 200 @{ ok = $true; msg = "Pro" }
    $r = Read-WebTestReply $c
    Assert-True ((Get-WebCode $r) -eq "200" -and $r -match '"msg": "Pro"') "web : reponse de l'action"
  } finally { $c.Close() }

  $c = Connect-WebTest
  try {
    Send-WebTestBytes $c (New-WebAsk "POST /api/action" @($tok, $json) $act)
    $null = Read-WebTestReply $c $true 300
    Stop-WebServer
    $r = Read-WebTestReply $c
    Assert-True ((Get-WebCode $r) -eq "409" -and $r -match "quitte le menu") "web : action en attente prevenue a la fermeture"
  } finally { $c.Close() }
  Assert-Null $script:Web "web : serveur arrete"
  $refused = $false
  try { (Connect-WebTest $web.Port).Close() } catch { $refused = $true }
  Assert-True $refused "web : plus rien n'ecoute apres l'arret"
  $old = $web.Token
  $web = Start-WebServer @{}
  Assert-True ($web.Token -ne $old) "web : nouveau jeton a chaque ouverture"
} finally { Restore-WebTestRoot }
