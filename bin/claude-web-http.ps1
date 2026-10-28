if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-json.ps1")) { . (Join-Path $PSScriptRoot "claude-json.ps1") }
$script:WebHeadMax = 8192
$script:WebBodyMax = 65536
$script:WebReadMs = 5000
$script:WebSendMs = 2000
$script:WebLatin = [Text.Encoding]::GetEncoding(28591)
$script:WebSingle = @("host", "content-length", "content-type", "origin", "cookie", "sec-fetch-site")
$script:WebStatus = @{ 200 = "OK"; 303 = "See Other"; 400 = "Bad Request"; 403 = "Forbidden"; 404 = "Not Found"; 405 = "Method Not Allowed"; 409 = "Conflict"; 413 = "Payload Too Large"; 415 = "Unsupported Media Type"; 500 = "Internal Server Error" }
$script:WebHeaders = "Cache-Control: no-store`r`nX-Content-Type-Options: nosniff`r`nReferrer-Policy: no-referrer`r`nX-Frame-Options: DENY`r`nCross-Origin-Opener-Policy: same-origin`r`nCross-Origin-Resource-Policy: same-origin`r`nContent-Security-Policy: default-src 'self'; img-src 'self' data:; frame-ancestors 'none'; base-uri 'none'; form-action 'none'`r`n"

function New-WebConn {
  param($Client, [double]$Now)
  $Client.SendTimeout = $script:WebSendMs
  $Client.NoDelay = $true
  return @{ Client = $Client; Stream = $Client.GetStream(); Buf = (New-Object IO.MemoryStream); Born = $Now; Req = $null }
}

function Close-WebConn {
  param($Conn)
  try { $Conn.Client.Close() } catch { Write-Verbose $_.Exception.Message }
}

function Test-WebGone {
  param($Conn)
  try { return $Conn.Client.Client.Poll(0, [Net.Sockets.SelectMode]::SelectRead) -and $Conn.Client.Available -eq 0 } catch { return $true }
}

function ConvertFrom-WebHead {
  param([string]$Head)
  $lines = $Head -split "`r`n"
  if ($lines[0] -cnotmatch '^([A-Z]{3,7}) (/[^\s]*) HTTP/1\.[01]$') { return $null }
  $target = $Matches[2].Split([char[]]"?", 2)
  $query = ""
  if ($target.Count -eq 2) { $query = $target[1] }
  $req = @{ Status = 0; Method = $Matches[1]; Path = $target[0]; Query = $query; Headers = @{}; Body = "" }
  for ($i = 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -notmatch '^([A-Za-z0-9-]+):[ \t]*(.*?)[ \t]*$') { return $null }
    $name = $Matches[1].ToLowerInvariant()
    if (-not $req.Headers.ContainsKey($name)) { $req.Headers[$name] = $Matches[2] }
    elseif ($script:WebSingle -contains $name) { return $null }
  }
  if ($req.Headers.ContainsKey("transfer-encoding")) { return $null }
  return $req
}

function ConvertFrom-WebBytes {
  param([byte[]]$Bytes)
  $text = $script:WebLatin.GetString($Bytes)
  $end = $text.IndexOf("`r`n`r`n", [StringComparison]::Ordinal)
  if ($end -lt 0 -and $Bytes.Length -le $script:WebHeadMax) { return $null }
  if ($end -lt 0 -or $end -gt $script:WebHeadMax) { return @{ Status = 400 } }
  $req = ConvertFrom-WebHead $text.Substring(0, $end)
  if ($null -eq $req) { return @{ Status = 400 } }
  $len = 0
  $cl = $req.Headers["content-length"]
  if ($null -ne $cl -and $cl -notmatch '^[0-9]{1,9}$') { return @{ Status = 400 } }
  if ($null -ne $cl) { $len = [int]$cl }
  if ($len -gt $script:WebBodyMax) { return @{ Status = 413 } }
  $start = $end + 4
  if ($Bytes.Length - $start -lt $len) { return $null }
  $req.Body = [Text.Encoding]::UTF8.GetString($Bytes, $start, $len)
  return $req
}

function Read-WebConn {
  param($Conn, [double]$Now)
  $c = $Conn.Client
  $chunk = New-Object byte[] 8192
  while ($c.Available -gt 0) {
    $n = $Conn.Stream.Read($chunk, 0, [math]::Min($chunk.Length, $c.Available))
    if ($n -le 0) { return "closed" }
    $Conn.Buf.Write($chunk, 0, $n)
    if ($Conn.Buf.Length -gt $script:WebHeadMax + $script:WebBodyMax + 4) { $Conn.Req = @{ Status = 413 }; return "ready" }
  }
  $req = ConvertFrom-WebBytes $Conn.Buf.ToArray()
  if ($null -ne $req) { $Conn.Req = $req; return "ready" }
  if ($Now - $Conn.Born -gt $script:WebReadMs -or (Test-WebGone $Conn)) { return "closed" }
  return "wait"
}

function Send-WebResponse {
  param($Conn, [int]$Code, [string]$Type, [byte[]]$Body, [string]$Extra = "")
  if ($null -eq $Body) { $Body = [byte[]]@() }
  $head = "HTTP/1.1 " + $Code + " " + $script:WebStatus[$Code] + "`r`nContent-Type: " + $Type + "`r`nContent-Length: " + $Body.Length + "`r`n" + $script:WebHeaders + $Extra + "Connection: close`r`n`r`n"
  try {
    $h = [Text.Encoding]::ASCII.GetBytes($head)
    $Conn.Stream.Write($h, 0, $h.Length)
    if ($Body.Length -gt 0) { $Conn.Stream.Write($Body, 0, $Body.Length) }
    $Conn.Stream.Flush()
  } catch { Write-Verbose $_.Exception.Message } finally { Close-WebConn $Conn }
}

function Send-WebJson {
  param($Conn, [int]$Code, $Data)
  Send-WebResponse $Conn $Code "application/json; charset=utf-8" ([Text.Encoding]::UTF8.GetBytes((ConvertTo-JsonText $Data)))
}
