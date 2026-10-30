$script:ClmInstallWaitMs = 30000
$script:ClmInstallPollMs = 100
$script:ClmReloadedName = "CLM_RELOADED"
$script:ClmReloaded = [Environment]::GetEnvironmentVariable($script:ClmReloadedName) -eq "1"
[Environment]::SetEnvironmentVariable($script:ClmReloadedName, $null)

function Wait-ClmInstall {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $stamp = Read-ClmStamp
  while ($stamp -ceq $script:ClmInstallingStamp -and $sw.ElapsedMilliseconds -lt $script:ClmInstallWaitMs) {
    Start-Sleep -Milliseconds $script:ClmInstallPollMs
    $stamp = Read-ClmStamp
  }
  return $stamp
}

function Test-ClmReloadNeeded {
  param([string]$Stamp)
  return -not $script:ClmReloaded -and -not (Test-ClmStampSteady $Stamp)
}

function Get-ClmReloadArgs {
  param([object[]]$Argv)
  $out = @($Argv)
  if ($out -notcontains "--updated") { $out += "--updated" }
  return ,$out
}

function Invoke-ClmReload {
  param([string]$Script, [object[]]$Argv)
  $exe = (Get-Process -Id $PID).Path
  [Environment]::SetEnvironmentVariable($script:ClmReloadedName, "1")
  $reloadArgs = Get-ClmReloadArgs $Argv
  & $exe -NoProfile -ExecutionPolicy Bypass -File $Script @reloadArgs
  exit $LASTEXITCODE
}
