if (-not (Test-Path Function:\Import-ClmModule)) { . (Join-Path $PSScriptRoot "claude-import.ps1") }
. Import-ClmModule claude-drive-auth, claude-text
$script:DriveLoginSeconds = 300
$script:DriveLoginReadMs = 5000

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
  $body = [Text.Encoding]::UTF8.GetBytes("<html><body><p>" + [Net.WebUtility]::HtmlEncode($Text) + "</p></body></html>")
  $head = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Type: text/html; charset=utf-8`r`nContent-Length: " + $body.Length + "`r`nConnection: close`r`n`r`n")
  $Stream.Write($head, 0, $head.Length)
  $Stream.Write($body, 0, $body.Length)
  $Stream.Flush()
}

function Receive-AuthCode {
  param($Listener, [int]$TimeoutSec, [string]$State)
  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  while ((Get-Date) -lt $deadline) {
    if (-not $Listener.Pending()) { Start-Sleep -Milliseconds 200; continue }
    $client = $Listener.AcceptTcpClient()
    $res = $null
    try {
      $client.ReceiveTimeout = $script:DriveLoginReadMs
      $client.SendTimeout = $script:DriveLoginReadMs
      $stream = $client.GetStream()
      $reader = New-Object IO.StreamReader($stream, [Text.Encoding]::ASCII, $false, 4096, $true)
      $res = ConvertFrom-AuthRequest ([string]$reader.ReadLine())
      if ($res.State -cne $State) { $res = $null }
      $text = Get-ClmText "drive.login.page.ignored"
      if ($null -ne $res -and $res.Code) { $text = Get-ClmText "drive.login.page.ok" }
      if ($null -ne $res -and $res.Error) { $text = Get-ClmText "drive.login.page.refused" @($res.Error) }
      Send-AuthPage $stream $text
    } catch [IO.IOException] { Write-Verbose $_.Exception.Message }
    finally { $client.Close() }
    if ($null -ne $res -and ($res.Code -or $res.Error)) { return $res }
  }
  throw (Get-ClmText "drive.login.timeout")
}

function Open-Browser {
  param([string]$Url)
  try {
    if ($script:OsName -eq "Windows") { Start-Process $Url }
    elseif ($script:OsName -eq "MacOS") { & open $Url }
    else { & xdg-open $Url 2>$null }
  } catch { Write-Verbose $_.Exception.Message }
}

function Invoke-DriveLogin {
  $c = Read-DriveConfig
  if ($null -eq $c) { $c = @{} }
  $pkce = New-PkcePair
  $state = [guid]::NewGuid().ToString("N")
  $listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
  $listener.Start()
  try {
    $redirect = "http://127.0.0.1:" + $listener.LocalEndpoint.Port
    $url = Get-DriveAuthUrl (Get-DriveClient $c).Id $redirect $pkce.Challenge $state
    Write-Host ("  " + (Get-ClmText "drive.login.browser"))
    Write-Host ("  " + $url)
    Open-Browser $url
    $res = Receive-AuthCode $listener $script:DriveLoginSeconds $state
  } finally { $listener.Stop() }
  if ($res.Error) { throw (Get-ClmText "drive.login.refused" @($res.Error)) }
  if ($res.State -ne $state) { throw (Get-ClmText "drive.login.unexpected") }
  $r = Request-DriveToken $c @{ grant_type = "authorization_code"; code = $res.Code; redirect_uri = $redirect; code_verifier = $pkce.Verifier }
  Set-DriveTokenResponse $c $r ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
  if ([string]::IsNullOrEmpty([string]$c["refreshToken"])) { throw (Get-ClmText "drive.login.no.refresh") }
  Clear-DriveFolders $c
  Save-DriveConfig $c
  return Get-ClmText "drive.login.done" @((Get-DrivePcName))
}
