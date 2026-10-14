. (Join-Path $PSScriptRoot "claude-drive-auth.ps1")
$script:DriveLoginSeconds = 300

function ConvertFrom-AuthRequest {
  param([string]$RequestLine)
  $out = @{ Code = $null; State = $null; Error = $null }
  if ($RequestLine -notmatch '^GET\s+[^\s?]*\?(\S+)') { return $out }
  foreach ($pair in $Matches[1].Split("&")) {
    $kv = $pair.Split("=", 2)
    if ($kv.Count -lt 2) { continue }
    $v = [Uri]::UnescapeDataString($kv[1].Replace("+", " "))
    if ($kv[0] -eq "code") { $out.Code = $v }
    elseif ($kv[0] -eq "state") { $out.State = $v }
    elseif ($kv[0] -eq "error") { $out.Error = $v }
  }
  return $out
}

function Send-AuthPage {
  param($Stream, [string]$Text)
  $body = [Text.Encoding]::UTF8.GetBytes("<html><body><p>" + $Text + "</p></body></html>")
  $head = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Type: text/html; charset=utf-8`r`nContent-Length: " + $body.Length + "`r`nConnection: close`r`n`r`n")
  $Stream.Write($head, 0, $head.Length)
  $Stream.Write($body, 0, $body.Length)
  $Stream.Flush()
}

function Receive-AuthCode {
  param($Listener, [int]$TimeoutSec)
  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  while ((Get-Date) -lt $deadline) {
    if (-not $Listener.Pending()) { Start-Sleep -Milliseconds 200; continue }
    $client = $Listener.AcceptTcpClient()
    try {
      $stream = $client.GetStream()
      $reader = New-Object IO.StreamReader($stream, [Text.Encoding]::ASCII, $false, 4096, $true)
      $res = ConvertFrom-AuthRequest ([string]$reader.ReadLine())
      $text = "clm : Drive connecte, tu peux fermer cet onglet"
      if ($res.Error) { $text = "clm : connexion refusee (" + $res.Error + ")" }
      Send-AuthPage $stream $text
    } finally { $client.Close() }
    if ($res.Code -or $res.Error) { return $res }
  }
  throw "delai depasse, aucune reponse de Google"
}

function Open-Browser {
  param([string]$Url)
  try {
    if ($script:OsName -eq "Windows") { Start-Process $Url }
    elseif ($script:OsName -eq "MacOS") { & open $Url }
    else { & xdg-open $Url 2>$null }
  } catch {}
}

function Read-DriveClient {
  param($Config)
  if ($Config["clientId"] -and $Config["clientSecret"]) { return }
  $Config["clientId"] = ([string](Read-Host "  client ID OAuth (Google Cloud)")).Trim()
  $Config["clientSecret"] = ([string](Read-Host "  secret client OAuth")).Trim()
  if (-not $Config["clientId"] -or -not $Config["clientSecret"]) { throw "client ID et secret requis" }
}

function Invoke-DriveLogin {
  $c = Read-DriveConfig
  if ($null -eq $c) { $c = @{} }
  Read-DriveClient $c
  $pkce = New-PkcePair
  $state = [guid]::NewGuid().ToString("N")
  $listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
  $listener.Start()
  try {
    $redirect = "http://127.0.0.1:" + $listener.LocalEndpoint.Port
    $url = Get-DriveAuthUrl ([string]$c["clientId"]) $redirect $pkce.Challenge $state
    Write-Host "  connexion Google dans le navigateur, sinon ouvrir ce lien :"
    Write-Host ("  " + $url)
    Open-Browser $url
    $res = Receive-AuthCode $listener $script:DriveLoginSeconds
  } finally { $listener.Stop() }
  if ($res.Error) { throw ("connexion refusee : " + $res.Error) }
  if ($res.State -ne $state) { throw "reponse Google inattendue" }
  $r = Request-DriveToken $c @{ grant_type = "authorization_code"; code = $res.Code; redirect_uri = $redirect; code_verifier = $pkce.Verifier }
  Set-DriveTokenResponse $c $r ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
  if ([string]::IsNullOrEmpty([string]$c["refreshToken"])) { throw "Google n'a pas rendu de jeton de renouvellement" }
  Save-DriveConfig $c
  return "Drive connecte sur " + (Get-DrivePcName)
}
