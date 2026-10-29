. Import-ClmModule claude-web-http
$script:WebBootMs = 60000
$script:WebBootPath = "/boot"
$script:WebBootBytes = 16
$script:WebTokenBytes = 24
$script:WebBootRefused = "lien de la page expire ou deja utilise : rouvrir la page depuis clm, touche w"

function New-WebSecret {
  param([int]$Size)
  $bytes = New-Object byte[] $Size
  $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
  try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
  return -join ($bytes | ForEach-Object { $_.ToString("x2") })
}

function Test-WebSecret {
  param([string]$Given, [string]$Want)
  if (-not $Given -or -not $Want) { return $false }
  $a = [Text.Encoding]::UTF8.GetBytes($Given)
  $b = [Text.Encoding]::UTF8.GetBytes($Want)
  $diff = $a.Length -bxor $b.Length
  for ($i = 0; $i -lt $b.Length; $i++) { $diff = $diff -bor ($b[$i] -bxor $a[$i % $a.Length]) }
  return $diff -eq 0
}

function Get-WebCookieName {
  param($Web)
  return "clm_" + $Web.Port
}

function Get-WebCookie {
  param($Req, [string]$Name)
  $raw = $Req.Headers["cookie"]
  if ($null -eq $raw) { return "" }
  foreach ($part in $raw.Split(";")) {
    $kv = $part.Trim().Split([char[]]"=", 2)
    if ($kv.Count -eq 2 -and $kv[0] -ceq $Name) { return $kv[1] }
  }
  return ""
}

function New-WebUrl {
  $w = $script:Web
  if ($null -eq $w) { return "" }
  $w.Boot = New-WebSecret $script:WebBootBytes
  $w.BootUntil = (Get-NowMs) + $script:WebBootMs
  return "http://" + $w.Host + $script:WebBootPath + "?c=" + $w.Boot
}

function Send-WebBoot {
  param($Web, $Conn)
  $given = ""
  if ($Conn.Req.Query -cmatch '^c=([0-9a-f]+)$') { $given = $Matches[1] }
  $fresh = $null -ne $Web.Boot -and (Get-NowMs) -le $Web.BootUntil
  if (-not $fresh -or -not (Test-WebSecret $given $Web.Boot)) {
    Send-WebResponse $Conn 403 "text/plain; charset=utf-8" ([Text.Encoding]::UTF8.GetBytes($script:WebBootRefused))
    return
  }
  $Web.Boot = $null
  $extra = "Set-Cookie: " + (Get-WebCookieName $Web) + "=" + $Web.Token + "; HttpOnly; SameSite=Strict; Path=/`r`nLocation: /`r`n"
  Send-WebResponse $Conn 303 "text/plain; charset=utf-8" ([byte[]]@()) $extra
}

function Get-WebRefusal {
  param($Web, $Req)
  if ($Req.Headers["host"] -cne $Web.Host) { return 403 }
  if (-not $Req.Path.StartsWith("/api/")) { return 0 }
  if (-not (Test-WebSecret (Get-WebCookie $Req (Get-WebCookieName $Web)) $Web.Token)) { return 403 }
  $site = $Req.Headers["sec-fetch-site"]
  if ($null -ne $site -and $site -cne "same-origin") { return 403 }
  $origin = $Req.Headers["origin"]
  if ($null -ne $origin -and $origin -cne $Web.Origin) { return 403 }
  if ($Req.Method -eq "POST" -and $Req.Headers["content-type"] -notmatch '^application/json(;|$)') { return 415 }
  return 0
}
