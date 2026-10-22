if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-keychain.ps1")) { . (Join-Path $PSScriptRoot "claude-keychain.ps1") }

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

function Write-CredentialFile {
  param([string]$Path, $Cred)
  $tmp = $Path + "." + [guid]::NewGuid().ToString("N") + ".tmp"
  $json = $Cred | ConvertTo-Json -Depth 10 -Compress
  [IO.File]::WriteAllText($tmp, $json, (New-Object Text.UTF8Encoding($false)))
  if ($script:OsName -ne "Windows") { try { & chmod 600 $tmp } catch {} }
  if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($tmp, $Path, [NullString]::Value) }
  else { [IO.File]::Move($tmp, $Path) }
}

function Write-AccountCredential {
  param($Acc, $Cred)
  $path = Get-AccountPath $Acc
  if ($script:OsName -eq "MacOS") {
    $dir = $null
    if ($Acc.Dir -ne ".claude") { $dir = $path }
    Write-KeychainCredential $dir ($Cred | ConvertTo-Json -Depth 10 -Compress)
    return
  }
  if (-not (Test-Path -LiteralPath $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
  Write-CredentialFile (Join-Path $path ".credentials.json") $Cred
}
