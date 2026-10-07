$script:KeychainAccount = "claude-code-user"

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

function Read-KeychainItem {
  param([string]$Service, [string]$Account)
  try { $v = & security find-generic-password -a $Account -w -s $Service 2>$null } catch { return $null }
  if ($LASTEXITCODE -ne 0 -or $v -eq $null) { return $null }
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
    if ($c -eq $null) { return $null }
    $b64 += $c
  }
  if ($b64.Length -ne $l) { return $null }
  try { return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64)) } catch { return $null }
}

function Read-KeychainCredential {
  param([string]$ConfigDir)
  $svc = Get-KeychainService $ConfigDir
  $acct = $script:KeychainAccount
  $meta = Read-KeychainItem $svc ($acct + "#m")
  if ($meta) { return Join-KeychainChunks $meta { param($k) Read-KeychainItem $svc ($acct + "#" + $k) } }
  $v = Read-KeychainItem $svc $acct
  if (-not $v -and $env:USER) { $v = Read-KeychainItem $svc $env:USER }
  return $v
}

function Read-AccountCredential {
  param($Acc)
  $raw = $null
  if ($script:OsName -eq "MacOS") {
    $dir = $null
    if ($Acc.Dir -ne ".claude") { $dir = Get-AccountPath $Acc }
    $raw = Read-KeychainCredential $dir
  }
  if (-not $raw) {
    try { $raw = Get-Content -LiteralPath (Join-Path (Get-AccountPath $Acc) ".credentials.json") -Raw -ErrorAction Stop } catch { return $null }
  }
  try { return $raw | ConvertFrom-Json } catch { return $null }
}

function Remove-KeychainCredential {
  param([string]$ConfigDir)
  $svc = Get-KeychainService $ConfigDir
  $acct = $script:KeychainAccount
  $names = @($acct, ($acct + "#m"))
  $meta = Read-KeychainItem $svc ($acct + "#m")
  if ($meta) {
    try { $n = [math]::Min([int](($meta | ConvertFrom-Json).n), 256) } catch { $n = 0 }
    for ($i = 0; $i -lt $n; $i++) { $names += $acct + "#" + $i }
  }
  foreach ($a in $names) { try { & security delete-generic-password -a $a -s $svc 2>$null | Out-Null } catch {} }
}
