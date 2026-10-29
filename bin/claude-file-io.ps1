. Import-ClmModule claude-platform
$script:LockPollMs = 200
$script:PrivateModeFailed = "droits du fichier prive impossibles a poser"

function Set-PrivateMode {
  param([string]$Path)
  if ($script:OsName -eq "Windows") { return }
  $global:LASTEXITCODE = 0
  & chmod 600 $Path
  if ($LASTEXITCODE -ne 0) { throw $script:PrivateModeFailed }
}

function Write-TextFileAtomic {
  param([string]$Path, [string]$Text, [switch]$Private, [switch]$Bom)
  $tmp = $Path + "." + [guid]::NewGuid().ToString("N") + ".tmp"
  try {
    [IO.File]::WriteAllBytes($tmp, [byte[]]@())
    if ($Private) { Set-PrivateMode $tmp }
    [IO.File]::WriteAllText($tmp, $Text, (New-Object Text.UTF8Encoding ([bool]$Bom)))
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

function Test-ReparsePath {
  param([string]$Path)
  try { $attr = [IO.File]::GetAttributes($Path) } catch [IO.IOException] { return $false }
  return [bool]($attr -band [IO.FileAttributes]::ReparsePoint)
}
