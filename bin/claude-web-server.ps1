if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-platform.ps1")) { . (Join-Path $PSScriptRoot "claude-platform.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-web-http.ps1")) { . (Join-Path $PSScriptRoot "claude-web-http.ps1") }
$script:Web = $null
$script:WebRoot = Join-Path $PSScriptRoot "clm-web"
$script:WebFiles = @("index.html", "style.css", "api.js", "ui.js", "tabs.js", "accounts.js", "prefs.js", "sync.js", "backups.js", "display.js")
$script:WebTypes = @{ ".html" = "text/html; charset=utf-8"; ".css" = "text/css; charset=utf-8"; ".js" = "text/javascript; charset=utf-8" }
$script:WebMaxConns = 16
$script:WebMaxActions = 8
$script:WebBusyText = "clm est occupe dans le terminal, reessayer quand il revient au menu"

function New-WebToken {
  $bytes = New-Object byte[] 24
  $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
  try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
  return -join ($bytes | ForEach-Object { $_.ToString("x2") })
}

function New-WebListener {
  $l = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
  if ($script:OsName -eq "Windows") { $l.ExclusiveAddressUse = $true }
  $l.Start()
  return $l
}

function Start-WebServer {
  param([hashtable]$Views)
  if ($null -ne $script:Web) { return $script:Web }
  $l = New-WebListener
  $port = $l.LocalEndpoint.Port
  $script:Web = @{
    Listener = $l; Port = $port; Token = (New-WebToken); Host = "127.0.0.1:" + $port; Origin = "http://127.0.0.1:" + $port; Views = $Views
    Conns = (New-Object 'System.Collections.Generic.List[object]'); Actions = (New-Object 'System.Collections.Generic.Queue[object]')
  }
  return $script:Web
}

function Stop-WebServer {
  $w = $script:Web
  if ($null -eq $w) { return }
  $script:Web = $null
  foreach ($c in $w.Conns) { Close-WebConn $c }
  while ($w.Actions.Count -gt 0) { Send-WebJson $w.Actions.Dequeue().Conn 409 @{ ok = $false; msg = "clm a quitte le menu" } }
  try { $w.Listener.Stop() } catch { Write-Verbose $_.Exception.Message }
}

function Get-WebUrl {
  if ($null -eq $script:Web) { return "" }
  return "http://" + $script:Web.Host + "/?t=" + $script:Web.Token
}

function Get-WebRefusal {
  param($Web, $Req)
  if ($Req.Headers["host"] -cne $Web.Host) { return 403 }
  if (-not $Req.Path.StartsWith("/api/")) { return 0 }
  if ($Req.Headers["x-clm-token"] -cne $Web.Token) { return 403 }
  $site = $Req.Headers["sec-fetch-site"]
  if ($null -ne $site -and $site -cne "same-origin") { return 403 }
  $origin = $Req.Headers["origin"]
  if ($null -ne $origin -and $origin -cne $Web.Origin) { return 403 }
  if ($Req.Method -eq "POST" -and $Req.Headers["content-type"] -notmatch '^application/json(;|$)') { return 415 }
  return 0
}

function Send-WebFile {
  param($Conn, [string]$Path)
  $name = $Path.Substring(1)
  if ($name -eq "") { $name = "index.html" }
  $file = $null
  if ($script:WebFiles -ccontains $name) { $file = Join-Path $script:WebRoot $name }
  if ($null -eq $file -or -not [IO.File]::Exists($file)) { Send-WebJson $Conn 404 @{ ok = $false; msg = "page introuvable" }; return }
  Send-WebResponse $Conn 200 $script:WebTypes[[IO.Path]::GetExtension($name)] ([IO.File]::ReadAllBytes($file))
}

function Send-WebView {
  param($Web, $Conn, [string]$Name)
  if ($null -eq $Web.Views -or -not $Web.Views.ContainsKey($Name)) { Send-WebJson $Conn 404 @{ ok = $false; msg = "donnee inconnue" }; return }
  try { $data = & $Web.Views[$Name] } catch { Send-WebJson $Conn 500 @{ ok = $false; msg = $_.Exception.Message }; return }
  Send-WebJson $Conn 200 $data
}

function Add-WebAction {
  param($Web, $Conn, [bool]$Open)
  $data = $null
  try { $data = ConvertFrom-JsonText $Conn.Req.Body } catch { $data = $null }
  if ($data -isnot [Collections.IDictionary]) { Send-WebJson $Conn 400 @{ ok = $false; msg = "action illisible" }; return }
  if (-not $Open -or $Web.Actions.Count -ge $script:WebMaxActions) { Send-WebJson $Conn 409 @{ ok = $false; msg = $script:WebBusyText }; return }
  $Web.Actions.Enqueue(@{ Conn = $Conn; Args = $data })
}

function Send-WebAnswer {
  param($Web, $Conn, [bool]$Open)
  $req = $Conn.Req
  if ($req.Status -ne 0) { Send-WebJson $Conn $req.Status @{ ok = $false; msg = "requete refusee" }; return }
  $no = Get-WebRefusal $Web $req
  if ($no -ne 0) { Send-WebJson $Conn $no @{ ok = $false; msg = "acces refuse" }; return }
  $api = $req.Path.StartsWith("/api/")
  if ($req.Method -eq "GET" -and -not $api) { Send-WebFile $Conn $req.Path; return }
  if ($req.Method -eq "GET") { Send-WebView $Web $Conn $req.Path.Substring(5); return }
  if ($req.Method -eq "POST" -and $req.Path -ceq "/api/action") { Add-WebAction $Web $Conn $Open; return }
  Send-WebJson $Conn 405 @{ ok = $false; msg = "methode refusee" }
}

function Receive-WebRequests {
  param([bool]$Open, [double]$Now = (Get-NowMs))
  $w = $script:Web
  if ($null -eq $w) { return }
  try { while ($w.Conns.Count -lt $script:WebMaxConns -and $w.Listener.Pending()) { $w.Conns.Add((New-WebConn $w.Listener.AcceptTcpClient() $Now)) } } catch { Write-Verbose $_.Exception.Message }
  for ($i = $w.Conns.Count - 1; $i -ge 0; $i--) {
    $c = $w.Conns[$i]
    $state = "closed"
    try { $state = Read-WebConn $c $Now } catch { $state = "closed" }
    if ($state -eq "wait") { continue }
    $w.Conns.RemoveAt($i)
    if ($state -eq "closed") { Close-WebConn $c; continue }
    try { Send-WebAnswer $w $c $Open } catch { Send-WebJson $c 500 @{ ok = $false; msg = $_.Exception.Message } }
  }
}

function Get-WebAction {
  $w = $script:Web
  if ($null -eq $w) { return $null }
  while ($w.Actions.Count -gt 0) {
    $a = $w.Actions.Dequeue()
    if (-not (Test-WebGone $a.Conn)) { return $a }
    Close-WebConn $a.Conn
  }
  return $null
}
