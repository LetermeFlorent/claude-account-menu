if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-file-io.ps1")) { . (Join-Path $PSScriptRoot "claude-file-io.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-state.ps1")) { . (Join-Path $PSScriptRoot "claude-state.ps1") }
$script:RegistryLockWaitMs = 5000
$script:RegistryUnreadableText = "liste des comptes illisible, copie gardee a cote"
$script:RegistryBusyText = "liste des comptes en cours d'ecriture"
$script:RegistryBadKey = ""

function Read-RegistryFile {
  $data = [IO.File]::ReadAllText($script:RegistryPath) | ConvertFrom-Json
  $list = @($data | ForEach-Object { $_ })
  foreach ($a in $list) {
    if ($a -isnot [PSCustomObject] -or [string]::IsNullOrEmpty([string]$a.Label) -or [string]::IsNullOrEmpty([string]$a.Dir)) { throw $script:RegistryUnreadableText }
  }
  return $list
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
  catch { Write-Verbose ("copie du registre illisible impossible : " + $_.Exception.Message) }
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
  Invoke-WithFileLock ($script:RegistryPath + ".lock") $script:RegistryLockWaitMs $script:RegistryBusyText {
    if (-not (Test-RegistryReadable)) { throw $script:RegistryUnreadableText }
    Write-TextFileAtomic $script:RegistryPath ((ConvertTo-Json -InputObject @($List) -Depth 3) + "`n") -Bom:($PSVersionTable.PSVersion.Major -lt 6)
  }
}
