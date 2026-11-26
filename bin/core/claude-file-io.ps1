. Import-ClmModule claude-platform
$script:LockPollMs = 200
$script:FileRetryAttempts = 3
$script:FileRetryDelayMs = 250
if ($PSVersionTable.PSVersion.Major -lt 6) { Add-Type -AssemblyName Microsoft.VisualBasic }

function Set-PrivateMode {
  param([string]$Path)
  if ($script:OsName -eq "Windows") { return }
  $global:LASTEXITCODE = 0
  & chmod 600 $Path
  if ($LASTEXITCODE -eq 0) { return }
  $key = "accounts.file.privateModeFailed"
  if (Test-Path Function:\Get-ClmText) { throw (Get-ClmText $key) }
  throw $key
}

function Test-FileBusy {
  param($Err)
  $e = $Err.Exception
  while ($e -is [Management.Automation.MethodInvocationException] -and $null -ne $e.InnerException) { $e = $e.InnerException }
  if ($e -is [IO.FileNotFoundException] -or $e -is [IO.DirectoryNotFoundException]) { return $false }
  return $e -is [IO.IOException] -or $e -is [UnauthorizedAccessException]
}

function Invoke-FileRetry {
  param([scriptblock]$Action)
  for ($attempt = 1; $attempt -le $script:FileRetryAttempts; $attempt++) {
    try {
      $out = & $Action
      if ($null -ne $out) { return ,$out }
      return
    } catch {
      if ($attempt -ge $script:FileRetryAttempts -or -not (Test-FileBusy $_)) { throw }
    }
    Start-Sleep -Milliseconds $script:FileRetryDelayMs
  }
}

function Move-FileReplacing {
  param([string]$From, [string]$To)
  if ($PSVersionTable.PSVersion.Major -ge 6) { [IO.File]::Move($From, $To, $true) }
  else { [Microsoft.VisualBasic.FileIO.FileSystem]::MoveFile($From, $To, $true) }
}

function Move-FileOver {
  param([string]$From, [string]$To)
  if ([IO.Directory]::Exists($To)) { Move-FileReplacing $From $To; return }
  Invoke-FileRetry { Move-FileReplacing $From $To }
}

function Read-SharedText {
  param([string]$Path)
  return Invoke-FileRetry { [IO.File]::ReadAllText($Path) }
}

function Write-TextFileAtomic {
  param([string]$Path, [string]$Text, [switch]$Private, [switch]$Bom)
  $tmp = $Path + "." + [guid]::NewGuid().ToString("N") + ".tmp"
  try {
    [IO.File]::WriteAllBytes($tmp, [byte[]]@())
    if ($Private) { Set-PrivateMode $tmp }
    [IO.File]::WriteAllText($tmp, $Text, (New-Object Text.UTF8Encoding ([bool]$Bom)))
    Move-FileOver $tmp $Path
  } finally {
    if ([IO.File]::Exists($tmp)) { [IO.File]::Delete($tmp) }
  }
}

function Test-SharingViolation {
  param($Err)
  $e = $Err.Exception
  while ($e -is [Management.Automation.MethodInvocationException] -and $null -ne $e.InnerException) { $e = $e.InnerException }
  if (-not ($e -is [IO.IOException])) { return $false }
  return -not ($e -is [IO.FileNotFoundException] -or $e -is [IO.DirectoryNotFoundException] -or $e -is [IO.PathTooLongException] -or $e -is [IO.DriveNotFoundException])
}

function Enter-FileLock {
  param([string]$Path, [int]$WaitMs)
  $deadline = [DateTime]::UtcNow.AddMilliseconds($WaitMs)
  while ($true) {
    try { return [IO.File]::Open($Path, "OpenOrCreate", "ReadWrite", "None") }
    catch {
      if (-not (Test-SharingViolation $_) -or [DateTime]::UtcNow -ge $deadline) { return $null }
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
