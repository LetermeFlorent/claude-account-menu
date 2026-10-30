. Import-ClmModule claude-file-io, claude-state, claude-text
$script:RegistryLockWaitMs = 5000
$script:RegistryBadKey = ""
$script:AccountLabelMax = 40
$script:AccountDirPattern = '^\.claude(-[A-Za-z0-9_-]+)?\z'
$script:AccountDirWarned = @{}

function Test-AccountDir {
  param($Dir)
  return ($Dir -is [string]) -and $Dir -cmatch $script:AccountDirPattern
}

function Select-ValidAccounts {
  param($List)
  foreach ($a in @($List)) {
    if (Test-AccountDir $a.Dir) { $a; continue }
    $shown = ([string]$a.Dir) -replace '[\x00-\x1f\x7f]', '?'
    if ($script:AccountDirWarned.ContainsKey($shown)) { continue }
    $script:AccountDirWarned[$shown] = $true
    Write-Warning (Get-ClmText "accounts.registry.badDir" @($shown))
  }
}

function ConvertTo-AccountLabel {
  param($Text)
  $clean = ([string]$Text) -replace '[\x00-\x1F\x7F-\x9F]', ''
  $clean = $clean.Trim()
  if ($clean.Length -gt $script:AccountLabelMax) { $clean = $clean.Substring(0, $script:AccountLabelMax).Trim() }
  return $clean
}

function Read-RegistryFile {
  $data = Read-SharedText $script:RegistryPath | ConvertFrom-Json
  $list = @($data | ForEach-Object { $_ })
  foreach ($a in $list) {
    if ($a -isnot [PSCustomObject] -or [string]::IsNullOrEmpty([string]$a.Label) -or [string]::IsNullOrEmpty([string]$a.Dir)) { throw (Get-ClmText "accounts.registry.unreadable") }
  }
  return @(Select-ValidAccounts $list)
}

function Test-RegistryReadable {
  if (-not (Test-Path -LiteralPath $script:RegistryPath)) { return $true }
  try { $null = Read-RegistryFile; return $true } catch { return $false }
}

function Save-RegistryBad {
  $info = Get-Item -LiteralPath $script:RegistryPath
  $key = $info.LastWriteTimeUtc.Ticks.ToString() + ":" + $info.Length
  if ($key -eq $script:RegistryBadKey) { return }
  $stamp = [DateTime]::Now.ToString("yyyyMMdd-HHmmss")
  $dest = $script:RegistryPath + ".bad-" + $stamp
  if (Test-Path -LiteralPath $dest) { $dest = $dest + "-" + [guid]::NewGuid().ToString("N").Substring(0, 6) }
  try { Copy-Item -LiteralPath $script:RegistryPath -Destination $dest -ErrorAction Stop; $script:RegistryBadKey = $key }
  catch { Write-Verbose (Get-ClmText "accounts.registry.badCopyFailed" @($_.Exception.Message)) }
}

function Get-DefaultAccounts {
  $list = @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" })
  foreach ($n in 2..9) {
    $d = ".claude-compte" + $n
    if (Test-Path -LiteralPath (Join-Path $script:HomeDir $d)) { $list += [PSCustomObject]@{ Label = "compte" + $n; Dir = $d } }
  }
  return $list
}

function Get-Accounts {
  if (Test-Path -LiteralPath $script:RegistryPath) {
    try { return Read-RegistryFile } catch { Save-RegistryBad; return Get-DefaultAccounts }
  }
  $list = Get-DefaultAccounts
  Save-Registry $list
  return $list
}

function Save-Registry {
  param($List)
  Invoke-WithFileLock ($script:RegistryPath + ".lock") $script:RegistryLockWaitMs (Get-ClmText "accounts.registry.busy") {
    if (-not (Test-RegistryReadable)) { throw (Get-ClmText "accounts.registry.unreadable") }
    Write-TextFileAtomic $script:RegistryPath ((ConvertTo-Json -InputObject @($List) -Depth 3) + "`n") -Bom:($PSVersionTable.PSVersion.Major -lt 6)
  }
}
