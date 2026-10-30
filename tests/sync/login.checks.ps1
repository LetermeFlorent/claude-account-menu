if (-not (Test-Path Function:\Invoke-DriveSetup)) { . (Join-Path $bin "claude-sync-passphrase.ps1") }
$loginMem = New-Object IO.MemoryStream
Send-AuthPage $loginMem "clm : connexion refusee (<script>alert(1)</script>&x)"
$loginHtml = [Text.Encoding]::UTF8.GetString($loginMem.ToArray())
Assert-True (-not $loginHtml.Contains("<script>")) "page de retour : balise de l'erreur neutralisee"
Assert-True ($loginHtml.Contains("&lt;script&gt;alert(1)&lt;/script&gt;&amp;x")) "page de retour : erreur encodee"
Assert-True ($loginHtml.Contains("Content-Length: " + [Text.Encoding]::UTF8.GetByteCount($loginHtml.Substring($loginHtml.IndexOf("<html>"))))) "page de retour : longueur annoncee exacte"

$loginListener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
$loginListener.Start()
$loginSaved = $script:DriveLoginReadMs
$script:DriveLoginReadMs = 300
$loginIdle = New-Object Net.Sockets.TcpClient
$loginReal = New-Object Net.Sockets.TcpClient
try {
  $loginPort = $loginListener.LocalEndpoint.Port
  $loginIdle.Connect("127.0.0.1", $loginPort)
  $loginReal.Connect("127.0.0.1", $loginPort)
  $loginBytes = [Text.Encoding]::ASCII.GetBytes("GET /?code=abc&state=st HTTP/1.1`r`n`r`n")
  $loginReal.GetStream().Write($loginBytes, 0, $loginBytes.Length)
  $loginWatch = [Diagnostics.Stopwatch]::StartNew()
  $loginRes = Receive-AuthCode $loginListener 20 "st"
  $loginWatch.Stop()
  Assert-Equal "abc" $loginRes.Code "connexion muette : la vraie reponse est quand meme lue"
  Assert-True ($loginWatch.ElapsedMilliseconds -lt 10000) ("connexion muette : abandonnee au bout du delai de lecture, " + $loginWatch.ElapsedMilliseconds + " ms")
} finally {
  $loginIdle.Close()
  $loginReal.Close()
  $loginListener.Stop()
  $script:DriveLoginReadMs = $loginSaved
}

$loginListener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
$loginListener.Start()
$loginForged = New-Object Net.Sockets.TcpClient
$loginGood = New-Object Net.Sockets.TcpClient
try {
  $loginPort = $loginListener.LocalEndpoint.Port
  $loginForged.Connect("127.0.0.1", $loginPort)
  $loginBytes = [Text.Encoding]::ASCII.GetBytes("GET /?error=access_denied&state=autre HTTP/1.1`r`n`r`n")
  $loginForged.GetStream().Write($loginBytes, 0, $loginBytes.Length)
  $loginGood.Connect("127.0.0.1", $loginPort)
  $loginBytes = [Text.Encoding]::ASCII.GetBytes("GET /?code=bon&state=st HTTP/1.1`r`n`r`n")
  $loginGood.GetStream().Write($loginBytes, 0, $loginBytes.Length)
  $loginRes = Receive-AuthCode $loginListener 20 "st"
  Assert-Equal "bon|" ($loginRes.Code + "|" + $loginRes.Error) "connexion : erreur d'un autre etat ignoree"
  $loginForgedText = (New-Object IO.StreamReader($loginForged.GetStream())).ReadToEnd()
  Assert-True (-not $loginForgedText.Contains((Get-ClmText "drive.login.page.refused" @("access_denied")))) "connexion : reponse d'un autre etat sans effet affiche"
} finally {
  $loginForged.Close()
  $loginGood.Close()
  $loginListener.Stop()
}
