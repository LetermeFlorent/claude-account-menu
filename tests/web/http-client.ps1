. (Join-Path $bin "claude-web-server.ps1")

$webRoot = Join-Path $script:Sandbox "web-root"
New-Item -ItemType Directory -Path $webRoot -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $webRoot "index.html"), "<p>clm</p>")
[IO.File]::WriteAllText((Join-Path $webRoot "style.css"), "p{}")
[IO.File]::WriteAllText((Join-Path $webRoot "secret.txt"), "non")
$webSavedRoot = $script:WebRoot
$script:WebRoot = $webRoot

function Connect-WebTest {
  param([int]$Port = 0)
  if ($Port -eq 0) { $Port = $script:Web.Port }
  $c = New-Object Net.Sockets.TcpClient
  $c.Connect([Net.IPAddress]::Loopback, $Port)
  return $c
}

function Send-WebTestBytes {
  param($Client, [string]$Text)
  $b = [Text.Encoding]::UTF8.GetBytes($Text)
  $Client.GetStream().Write($b, 0, $b.Length)
}

function Read-WebTestReply {
  param($Client, [bool]$Open = $false, [int]$WaitMs = 1500)
  $out = New-Object IO.MemoryStream
  $buf = New-Object byte[] 8192
  $end = [DateTime]::UtcNow.AddMilliseconds($WaitMs)
  while ([DateTime]::UtcNow -lt $end) {
    Receive-WebRequests $Open
    if ($Client.Available -gt 0) { $n = $Client.GetStream().Read($buf, 0, $buf.Length); $out.Write($buf, 0, $n); continue }
    if ($Client.Client.Poll(0, [Net.Sockets.SelectMode]::SelectRead) -and $Client.Available -eq 0) { break }
    Start-Sleep -Milliseconds 10
  }
  return [Text.Encoding]::UTF8.GetString($out.ToArray())
}

function Invoke-WebTest {
  param([string]$Text, [bool]$Open = $false)
  $c = Connect-WebTest
  try { Send-WebTestBytes $c $Text; return Read-WebTestReply $c $Open } finally { $c.Close() }
}

function New-WebAsk {
  param([string]$Line, [string[]]$Extra = @(), [string]$Body = "", [string]$HostName = "")
  if (-not $HostName) { $HostName = $script:Web.Host }
  $t = $Line + " HTTP/1.1`r`nHost: " + $HostName + "`r`n"
  foreach ($e in $Extra) { $t += $e + "`r`n" }
  if ($Body) { $t += "Content-Length: " + [Text.Encoding]::UTF8.GetByteCount($Body) + "`r`n" }
  return $t + "`r`n" + $Body
}

function Get-WebCode {
  param([string]$Reply)
  if ($Reply -match '^HTTP/1\.1 ([0-9]{3}) ') { return $Matches[1] }
  return "aucune"
}

function Restore-WebTestRoot {
  Stop-WebServer
  $script:WebRoot = $webSavedRoot
}
