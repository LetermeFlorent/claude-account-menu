. (Join-Path $bin "claude-menu-loop.ps1")
. (Join-Path $bin "claude-menu-startup.ps1")
. (Join-Path $bin "claude-menu-rename.ps1")
. (Join-Path $bin "claude-menu-remove.ps1")
. (Join-Path $bin "claude-menu-prefs.ps1")
. (Join-Path $bin "claude-menu-save.ps1")
. (Join-Path $bin "claude-cli.ps1")

$mwMocked = @("Read-UiInput", "Open-Browser", "Start-WebServer", "Open-MenuWeb", "Read-MenuAction", "Invoke-MenuCommand", "Close-AccountMenu", "Step-MenuFrame", "Enter-UiScreen", "Open-MenuSession", "Invoke-MenuLoop")
$mwKept = @{}
foreach ($n in $mwMocked) { $mwKept[$n] = (Get-Item ("function:" + $n)).ScriptBlock }
$mwSaved = @{ Menu = $script:MenuState; Startup = $script:Startup; Web = $script:Web; Poll = $script:UiPoll; Open = $script:WebOpen; Reopen = $script:WebReopen; Drive = $script:DriveJob }

function Set-MwReal {
  param([string]$Name)
  Set-Item ("function:" + $Name) $mwKept[$Name]
}

function New-MwState {
  $acc = [PSCustomObject]@{ Label = "perso"; Dir = ".claude" }
  return @{ Entries = @(@{ Acc = $acc; U = $null; Pending = $true; Seen = $false }); Sel = 0; Msg = @("", $script:Ink.Dim); Dirty = $false; Version = "clm v1" }
}

function Send-MwAsk {
  param([string]$Line, [string]$Body = "")
  $c = New-Object Net.Sockets.TcpClient
  $c.Connect([Net.IPAddress]::Loopback, $script:Web.Port)
  $t = $Line + " HTTP/1.1`r`nHost: " + $script:Web.Host + "`r`nCookie: " + (Get-WebCookieName $script:Web) + "=" + $script:Web.Token + "`r`n"
  if ($Body) { $t += "Content-Type: application/json`r`nContent-Length: " + $Body.Length + "`r`n" }
  $b = [Text.Encoding]::UTF8.GetBytes($t + "`r`n" + $Body)
  $c.GetStream().Write($b, 0, $b.Length)
  return $c
}

function Read-MwReply {
  param($Client)
  $out = New-Object IO.MemoryStream
  $buf = New-Object byte[] 8192
  $end = [DateTime]::UtcNow.AddMilliseconds(1500)
  while ([DateTime]::UtcNow -lt $end) {
    if ($Client.Available -gt 0) { $n = $Client.GetStream().Read($buf, 0, $buf.Length); $out.Write($buf, 0, $n); continue }
    if ($Client.Client.Poll(0, [Net.Sockets.SelectMode]::SelectRead) -and $Client.Available -eq 0) { break }
    Start-Sleep -Milliseconds 10
  }
  $Client.Close()
  return [Text.Encoding]::UTF8.GetString($out.ToArray())
}

function Wait-MwAction {
  $end = [DateTime]::UtcNow.AddMilliseconds(1500)
  while ([DateTime]::UtcNow -lt $end) {
    $a = Read-MenuAction $script:MenuState
    if ($a.Name -ne "none") { return $a }
    Start-Sleep -Milliseconds 10
  }
  return $a
}

function Restore-MwFakes {
  foreach ($n in $mwMocked) { Set-MwReal $n }
  if ($null -ne $script:Web) { Stop-WebServer }
  $script:MenuState = $mwSaved.Menu
  $script:Startup = $mwSaved.Startup
  $script:Web = $mwSaved.Web
  $script:UiPoll = $mwSaved.Poll
  $script:WebOpen = $mwSaved.Open
  $script:WebReopen = $mwSaved.Reopen
  $script:DriveJob = $mwSaved.Drive
}
