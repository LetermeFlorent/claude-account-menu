. Import-ClmModule claude-platform, claude-web-page, claude-text, claude-web-http, claude-web-auth, claude-web-errors
$script:Web = $null
$script:WebMaxConns = 16
$script:WebMaxActions = 8

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
    Listener = $l; Port = $port; Token = (New-WebSecret $script:WebTokenBytes); Boot = $null; BootUntil = 0; Host = "127.0.0.1:" + $port; Origin = "http://127.0.0.1:" + $port; Views = $Views
    Conns = (New-Object 'System.Collections.Generic.List[object]'); Actions = (New-Object 'System.Collections.Generic.Queue[object]')
  }
  return $script:Web
}

function Stop-WebServer {
  $w = $script:Web
  if ($null -eq $w) { return }
  $script:Web = $null
  foreach ($c in $w.Conns) { Close-WebConn $c }
  while ($w.Actions.Count -gt 0) { Send-WebJson $w.Actions.Dequeue().Conn 409 @{ ok = $false; msg = (Get-ClmText "server.menuLeft") } }
  try { $w.Listener.Stop() } catch { Write-Verbose $_.Exception.Message }
}

function Send-WebFile {
  param($Conn, [string]$Path)
  $name = $Path.Substring(1)
  if ($name -eq "") { $name = "index.html" }
  if (-not $script:WebPage.ContainsKey($name)) { Send-WebJson $Conn 404 @{ ok = $false; msg = (Get-ClmText "server.notFound") }; return }
  $file = $script:WebPage[$name]
  Send-WebResponse $Conn 200 $file.Type $file.Bytes
}

function Send-WebView {
  param($Web, $Conn, [string]$Name)
  if ($null -eq $Web.Views -or -not $Web.Views.ContainsKey($Name)) { Send-WebJson $Conn 404 @{ ok = $false; msg = (Get-ClmText "server.unknownView") }; return }
  try { $data = & $Web.Views[$Name] } catch { Send-WebJson $Conn 500 @{ ok = $false; msg = (Get-WebHiddenText $_ "W1") }; return }
  Send-WebJson $Conn 200 $data
}

function Add-WebAction {
  param($Web, $Conn, [bool]$Open)
  $data = $null
  try { $data = ConvertFrom-JsonText $Conn.Req.Body } catch { $data = $null }
  if ($data -isnot [Collections.IDictionary]) { Send-WebJson $Conn 400 @{ ok = $false; msg = (Get-ClmText "server.unreadableAction") }; return }
  if (-not $Open -or $Web.Actions.Count -ge $script:WebMaxActions) { Send-WebJson $Conn 409 @{ ok = $false; msg = (Get-ClmText "server.busy") }; return }
  $Web.Actions.Enqueue(@{ Conn = $Conn; Args = $data })
}

function Send-WebAnswer {
  param($Web, $Conn, [bool]$Open)
  $req = $Conn.Req
  if ($req.Status -ne 0) { Send-WebJson $Conn $req.Status @{ ok = $false; msg = (Get-ClmText "server.badRequest") }; return }
  $no = Get-WebRefusal $Web $req
  if ($no -ne 0) { Send-WebJson $Conn $no @{ ok = $false; msg = (Get-ClmText "server.denied") }; return }
  $api = $req.Path.StartsWith("/api/")
  if ($req.Method -eq "GET" -and $req.Path -ceq $script:WebBootPath) { Send-WebBoot $Web $Conn; return }
  if ($req.Method -eq "GET" -and -not $api) { Send-WebFile $Conn $req.Path; return }
  if ($req.Method -eq "GET") { Send-WebView $Web $Conn $req.Path.Substring(5); return }
  if ($req.Method -eq "POST" -and $req.Path -ceq "/api/action") { Add-WebAction $Web $Conn $Open; return }
  Send-WebJson $Conn 405 @{ ok = $false; msg = (Get-ClmText "server.badMethod") }
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
    try { Send-WebAnswer $w $c $Open } catch { Send-WebJson $c 500 @{ ok = $false; msg = (Get-WebHiddenText $_ "W2") } }
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
