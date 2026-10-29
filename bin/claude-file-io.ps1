. Import-ClmModule claude-platform
$script:LockPollMs = 200
$script:SharedWaitMs = 3000
$script:SharedPollMs = 20
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

function Test-SharedBusy {
  param($Err, [datetime]$Deadline)
  $e = $Err.Exception
  while ($e -is [Management.Automation.MethodInvocationException] -and $null -ne $e.InnerException) { $e = $e.InnerException }
  if ($e -is [IO.FileNotFoundException] -or $e -is [IO.DirectoryNotFoundException]) { return $false }
  if (-not ($e -is [IO.IOException] -or $e -is [UnauthorizedAccessException])) { return $false }
  if ([DateTime]::UtcNow -ge $Deadline) { return $false }
  Start-Sleep -Milliseconds $script:SharedPollMs
  return $true
}

function Move-FileReplacing {
  param([string]$From, [string]$To)
  if ($PSVersionTable.PSVersion.Major -ge 6) { [IO.File]::Move($From, $To, $true) }
  else { [Microsoft.VisualBasic.FileIO.FileSystem]::MoveFile($From, $To, $true) }
}

function Move-FileOver {
  param([string]$From, [string]$To)
  $deadline = [DateTime]::UtcNow.AddMilliseconds($script:SharedWaitMs)
  while ($true) {
    try { Move-FileReplacing $From $To; return }
    catch { if ([IO.Directory]::Exists($To) -or -not (Test-SharedBusy $_ $deadline)) { throw } }
  }
}

function Read-SharedText {
  param([string]$Path)
  $deadline = [DateTime]::UtcNow.AddMilliseconds($script:SharedWaitMs)
  while ($true) {
    try { return [IO.File]::ReadAllText($Path) } catch { if (-not (Test-SharedBusy $_ $deadline)) { throw } }
  }
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
