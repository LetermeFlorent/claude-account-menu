if (-not (Test-Path Function:\Import-ClmModule)) { . (Join-Path $PSScriptRoot "../claude-import.ps1") }
. Import-ClmModule claude-platform
$script:StatusStateLockWaitMs = 500
$script:StatusStateLockPollMs = 25
$script:StatusLockTools = @("flock", "perl")
$script:StatusLockReady = "locked"
$script:StatusPerlLock = 'use Fcntl qw(:flock); open(my $f, ">>", $ARGV[0]) or exit 1; for (0 .. $ARGV[1]) { if (flock($f, LOCK_EX | LOCK_NB)) { $| = 1; print "locked\n"; my $x = <STDIN>; exit 0 } select(undef, undef, undef, 0.025) } exit 1'

function Open-WindowsStateLock {
  param([string]$Path, [int]$WaitMs)
  $fs = [IO.File]::Open($Path, "OpenOrCreate", "ReadWrite", "ReadWrite, Delete")
  $deadline = [DateTime]::UtcNow.AddMilliseconds($WaitMs)
  while ($true) {
    try { $fs.Lock(0, 1); return $fs }
    catch {
      if ([DateTime]::UtcNow -ge $deadline) { $fs.Dispose(); return $null }
      Start-Sleep -Milliseconds $script:StatusStateLockPollMs
    }
  }
}

function Get-StatusLockArgs {
  param([string]$Tool, [string]$Path, [int]$WaitMs)
  if ($Tool -eq "perl") { return @("-e", $script:StatusPerlLock, $Path, [string][math]::Ceiling($WaitMs / $script:StatusStateLockPollMs)) }
  $wait = @("-n")
  if ($WaitMs -gt 0) { $wait = @("-w", ($WaitMs / 1000.0).ToString([Globalization.CultureInfo]::InvariantCulture)) }
  return @("-x") + $wait + @($Path, "sh", "-c", ("echo " + $script:StatusLockReady + "; read x"))
}

function Open-UnixStateLock {
  param([string]$Path, [int]$WaitMs)
  foreach ($tool in $script:StatusLockTools) {
    $cmd = Get-Command $tool -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $cmd) { continue }
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $cmd.Source
    foreach ($a in (Get-StatusLockArgs $tool $Path $WaitMs)) { $psi.ArgumentList.Add($a) }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $p = [Diagnostics.Process]::Start($psi)
    try {
      $null = $p.StandardError.ReadToEndAsync()
      if ($p.StandardOutput.ReadLine() -ceq $script:StatusLockReady) { return $p }
      $p.WaitForExit()
    } catch {
      Write-Verbose $_.Exception.Message
      if (-not $p.HasExited) { $p.Kill() }
    }
    $p.Dispose()
    return $null
  }
  return $null
}

function Open-StatusStateLock {
  param([string]$State, [int]$WaitMs = $script:StatusStateLockWaitMs)
  $path = $State + ".lock"
  try {
    if ($script:OsName -eq "Windows") { return Open-WindowsStateLock $path $WaitMs }
    return Open-UnixStateLock $path $WaitMs
  } catch { Write-Verbose $_.Exception.Message; return $null }
}

function Close-StatusStateLock {
  param($Lock)
  if ($null -eq $Lock) { return }
  if ($Lock -is [IO.FileStream]) {
    try { $Lock.Unlock(0, 1) } catch { Write-Verbose $_.Exception.Message } finally { $Lock.Dispose() }
    return
  }
  try {
    $Lock.StandardInput.Close()
    if (-not $Lock.WaitForExit(1000)) { $Lock.Kill() }
  } catch { Write-Verbose $_.Exception.Message } finally { $Lock.Dispose() }
}
