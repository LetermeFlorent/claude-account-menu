. (Join-Path $PSScriptRoot "claude-update-parse.ps1")
$script:ReleaseBase = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"

function Get-HostArch {
  $a = "" + $env:PROCESSOR_ARCHITEW6432
  if ($a -eq "") { $a = "" + $env:PROCESSOR_ARCHITECTURE }
  if ($a -eq "") { try { $a = "" + [Runtime.InteropServices.RuntimeInformation]::OSArchitecture } catch {} }
  return $a.ToLower()
}

function Test-Musl {
  if ($script:OsName -ne "Linux") { return $false }
  return [bool](Get-ChildItem -Path "/lib" -Filter "ld-musl-*" -ErrorAction SilentlyContinue)
}

function Get-ReleaseSize {
  param([string]$Version)
  $plat = Get-ManifestPlatform $script:OsName (Get-HostArch) (Test-Musl)
  $ProgressPreference = "SilentlyContinue"
  try { $m = Invoke-RestMethod -Uri ($script:ReleaseBase + "/" + $Version + "/manifest.json") -TimeoutSec 5 } catch { return [long]0 }
  $e = Get-ManifestEntry $m $plat
  if ($e -eq $null) { return [long]0 }
  return $e.Size
}

function New-StagingWatch {
  param([string]$Version, [int]$ProcessId, [double]$Now)
  return @{ Root = (Get-StagingRoot); Version = $Version; Pid = $ProcessId; File = $null; Seen = $false; Settled = $false; Bytes = [long]0; Size = (Get-ReleaseSize $Version); Changed = $Now }
}

function Find-StagingFile {
  param($Watch)
  try { $dirs = [IO.Directory]::GetDirectories($Watch.Root) } catch { return $null }
  foreach ($d in $dirs) {
    if (Test-StagingDirName ([IO.Path]::GetFileName($d)) $Watch.Version $Watch.Pid) { return [IO.Path]::Combine($d, (Get-ClaudeExeName)) }
  }
  return $null
}

function Get-LiveLength {
  param([string]$Path)
  try {
    $fs = [IO.File]::Open($Path, "Open", "Read", "ReadWrite, Delete")
    try { return [long]$fs.Length } finally { $fs.Dispose() }
  } catch { return [long]-1 }
}

function Update-StagingWatch {
  param($Watch, [double]$Now)
  if ($Watch.Settled) { return }
  if (-not $Watch.File) {
    $Watch.File = Find-StagingFile $Watch
    if (-not $Watch.File) { return }
  }
  $n = Get-LiveLength $Watch.File
  if ($n -lt 0) {
    if ($Watch.Seen) { $Watch.Settled = $true }
    return
  }
  if (-not $Watch.Seen -or $n -ne $Watch.Bytes) { $Watch.Changed = $Now }
  $Watch.Seen = $true
  $Watch.Bytes = $n
  if ($Watch.Size -gt 0 -and $n -ge $Watch.Size) { $Watch.Settled = $true }
}

function Start-UpdateProcess {
  param([string]$Exe)
  $psi = New-Object Diagnostics.ProcessStartInfo
  $psi.FileName = $Exe
  $psi.Arguments = "update"
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $psi.RedirectStandardInput = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
  $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
  try { $p = [Diagnostics.Process]::Start($psi) } catch { return $null }
  try { $p.PriorityClass = "BelowNormal" } catch {}
  try { $p.StandardInput.Close() } catch {}
  return $p
}

function Stop-UpdateProcess {
  param($Proc)
  try { $Proc.Kill($true); return } catch {}
  if ($script:OsName -eq "Windows") {
    & taskkill.exe /T /F /PID $Proc.Id 2>&1 | Out-Null
    $null = $Proc.WaitForExit(2000)
  }
  if (-not $Proc.HasExited) { try { $Proc.Kill() } catch {} }
}

function New-LineSource {
  param($Reader)
  return @{ Reader = $Reader; Task = $Reader.ReadLineAsync(); Eof = $false }
}

function Receive-Lines {
  param($Src)
  $out = @()
  while (-not $Src.Eof -and $Src.Task.IsCompleted) {
    $l = $null
    try { $l = $Src.Task.Result } catch {}
    if ($l -eq $null) { $Src.Eof = $true }
    else { $out += $l; $Src.Task = $Src.Reader.ReadLineAsync() }
  }
  return $out
}
