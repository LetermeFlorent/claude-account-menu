$script:KeychainAccount = "claude-code-user"
$script:KeychainChunkSize = 1800

function Get-KeychainService {
  param([string]$ConfigDir)
  $name = "Claude Code-credentials"
  if ([string]::IsNullOrEmpty($ConfigDir)) { return $name }
  $sha = [Security.Cryptography.SHA256]::Create()
  try { $bytes = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($ConfigDir.Normalize([Text.NormalizationForm]::FormC))) }
  finally { $sha.Dispose() }
  $hex = -join ($bytes | ForEach-Object { $_.ToString("x2") })
  return $name + "-" + $hex.Substring(0, 8)
}

function Get-KeychainAccounts {
  $list = @($script:KeychainAccount)
  if ($env:USER -and $env:USER -ne $script:KeychainAccount) { $list += $env:USER }
  return $list
}

function Read-KeychainItem {
  param([string]$Service, [string]$Account)
  try { $v = & security find-generic-password -a $Account -w -s $Service 2>$null } catch { return $null }
  if ($LASTEXITCODE -ne 0 -or $null -eq $v) { return $null }
  $s = (@($v) -join "`n").Trim()
  if ($s -eq "") { return $null }
  return $s
}

function Join-KeychainChunks {
  param([string]$Meta, [scriptblock]$ReadChunk)
  try { $m = $Meta | ConvertFrom-Json } catch { return $null }
  $n = [int]$m.n; $l = [int]$m.l
  if ($n -le 0 -or $n -gt 256 -or $l -le 0) { return $null }
  $b64 = ""
  for ($i = 0; $i -lt $n; $i++) {
    $c = & $ReadChunk $i
    if ($null -eq $c) { return $null }
    $b64 += $c
  }
  if ($b64.Length -ne $l) { return $null }
  try { return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64)) } catch { return $null }
}

function Get-KeychainChunkCount {
  param([string]$Service, [string]$Account)
  $meta = Read-KeychainItem $Service ($Account + "#m")
  if (-not $meta) { return 0 }
  try { return [math]::Min([int](($meta | ConvertFrom-Json).n), 256) } catch { return 0 }
}

function Read-KeychainCredential {
  param([string]$ConfigDir)
  $svc = Get-KeychainService $ConfigDir
  $best = $null
  $bestExp = [long]-1
  foreach ($acct in Get-KeychainAccounts) {
    $found = @(Read-KeychainItem $svc $acct)
    $meta = Read-KeychainItem $svc ($acct + "#m")
    if ($meta) { $found += Join-KeychainChunks $meta { param($k) Read-KeychainItem $svc ($acct + "#" + $k) } }
    foreach ($v in $found) {
      if (-not $v) { continue }
      try { $exp = [long]($v | ConvertFrom-Json).claudeAiOauth.expiresAt } catch { continue }
      if ($exp -gt $bestExp) { $best = $v; $bestExp = $exp }
    }
  }
  return $best
}

function Select-KeychainAccount {
  param([string]$Service)
  foreach ($a in Get-KeychainAccounts) {
    if ((Read-KeychainItem $Service $a) -or (Read-KeychainItem $Service ($a + "#m"))) { return $a }
  }
  return $script:KeychainAccount
}

function ConvertTo-KeychainLine {
  param([string]$Service, [string]$Account, [string]$Value)
  $hex = -join ([Text.Encoding]::UTF8.GetBytes($Value) | ForEach-Object { $_.ToString("x2") })
  return 'add-generic-password -U -a "' + $Account + '" -s "' + $Service + '" -X "' + $hex + '"'
}

function Remove-KeychainItems {
  param([string]$Service, [string[]]$Accounts)
  foreach ($a in $Accounts) { try { & security delete-generic-password -a $a -s $Service 2>$null | Out-Null } catch {} }
}

function Write-KeychainCredential {
  param([string]$ConfigDir, [string]$Json)
  $svc = Get-KeychainService $ConfigDir
  $acct = Select-KeychainAccount $svc
  $old = Get-KeychainChunkCount $svc $acct
  $lines = @()
  $stale = @()
  if ([Text.Encoding]::UTF8.GetByteCount($Json) -le $script:KeychainChunkSize) {
    $lines += ConvertTo-KeychainLine $svc $acct $Json
    $n = 0
    if ($old -gt 0) { $stale += $acct + "#m" }
  } else {
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Json))
    $n = [int][math]::Ceiling($b64.Length / $script:KeychainChunkSize)
    for ($i = 0; $i -lt $n; $i++) {
      $start = $i * $script:KeychainChunkSize
      $lines += ConvertTo-KeychainLine $svc ($acct + "#" + $i) $b64.Substring($start, [math]::Min($script:KeychainChunkSize, $b64.Length - $start))
    }
    $lines += ConvertTo-KeychainLine $svc ($acct + "#m") ('{"n":' + $n + ',"l":' + $b64.Length + '}')
    $stale += $acct
  }
  $lines | & security -i 2>$null | Out-Null
  if ((Read-KeychainCredential $ConfigDir) -ne $Json) { throw "trousseau : ecriture refusee" }
  for ($i = $n; $i -lt $old; $i++) { $stale += $acct + "#" + $i }
  Remove-KeychainItems $svc $stale
}

function Remove-KeychainCredential {
  param([string]$ConfigDir)
  $svc = Get-KeychainService $ConfigDir
  $names = @()
  foreach ($a in Get-KeychainAccounts) {
    $names += @($a, ($a + "#m"))
    $n = Get-KeychainChunkCount $svc $a
    for ($i = 0; $i -lt $n; $i++) { $names += $a + "#" + $i }
  }
  Remove-KeychainItems $svc $names
}
