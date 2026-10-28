if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-platform.ps1")) { . (Join-Path $PSScriptRoot "claude-platform.ps1") }
$script:LockPollMs = 200
$script:PrivateModeFailed = "droits du fichier prive impossibles a poser"

function Write-TextFileAtomic {
  param([string]$Path, [string]$Text, [switch]$Private)
  $tmp = $Path + "." + [guid]::NewGuid().ToString("N") + ".tmp"
  try {
    [IO.File]::WriteAllBytes($tmp, [byte[]]@())
    if ($Private -and $script:OsName -ne "Windows") {
      $global:LASTEXITCODE = 0
      & chmod 600 $tmp
      if ($LASTEXITCODE -ne 0) { throw $script:PrivateModeFailed }
    }
    [IO.File]::WriteAllText($tmp, $Text, (New-Object Text.UTF8Encoding $false))
    if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($tmp, $Path, [NullString]::Value) }
    else { [IO.File]::Move($tmp, $Path) }
  } finally {
    if ([IO.File]::Exists($tmp)) { [IO.File]::Delete($tmp) }
  }
}

function Enter-FileLock {
  param([string]$Path, [int]$WaitMs)
  $deadline = [DateTime]::UtcNow.AddMilliseconds($WaitMs)
  while ($true) {
    try { return [IO.File]::Open($Path, "OpenOrCreate", "ReadWrite", "None") }
    catch {
      if ([DateTime]::UtcNow -ge $deadline) { return $null }
      Start-Sleep -Milliseconds $script:LockPollMs
    }
  }
}

function Invoke-WithFileLock {
  param([string]$Path, [int]$WaitMs, [string]$Message, [scriptblock]$Action)
  $fs = Enter-FileLock $Path $WaitMs
  if ($null -eq $fs) { throw $Message }
  try { & $Action } finally { $fs.Dispose() }
}
