if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-file-io.ps1")) { . (Join-Path $PSScriptRoot "claude-file-io.ps1") }
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
  Write-TextFileAtomic $Path ($Cred | ConvertTo-Json -Depth 10 -Compress) -Private
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
