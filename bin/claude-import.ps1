$script:ClmModuleDir = $PSScriptRoot
$script:ClmInstallingStamp = "installing"
$script:ClmInstallStaleSeconds = 120

function Import-ClmModule {
  param([string[]]$ClmImportNames)
  foreach ($ClmImportName in $ClmImportNames) {
    if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add($ClmImportName)) { . (Join-Path $script:ClmModuleDir ($ClmImportName + ".ps1")) }
  }
  Remove-Variable ClmImportNames, ClmImportName -ErrorAction Ignore
}

function Read-ClmStamp {
  param([string]$Dir = $script:ClmModuleDir)
  $marker = [IO.Path]::Combine($Dir, "clm.installing")
  $version = [IO.Path]::Combine($Dir, "clm.version")
  try {
    if ([IO.File]::Exists($marker) -and [DateTime]::UtcNow.Subtract([IO.File]::GetLastWriteTimeUtc($marker)).TotalSeconds -lt $script:ClmInstallStaleSeconds) { return $script:ClmInstallingStamp }
    if ([IO.File]::Exists($version)) { return [IO.File]::ReadAllText($version).Trim() }
  } catch { return $script:ClmInstallingStamp }
  return ""
}

function Test-ClmStampSteady {
  param([string]$Before)
  return $Before -cne $script:ClmInstallingStamp -and (Read-ClmStamp) -ceq $Before
}

$script:ClmGuardedLoad = @'
$clmEntry = Join-Path (Split-Path -Parent $Source) "claude-import.ps1"
$clmStamp = $null
if ([IO.File]::Exists($clmEntry)) { . $clmEntry; if (Test-Path Function:\Read-ClmStamp) { $clmStamp = Read-ClmStamp } }
try { if ($clmStamp -cne "installing") { . $Source } } catch { if ($null -eq $clmStamp -or (Test-ClmStampSteady $clmStamp)) { throw } }
$clmReplaced = $null -ne $clmStamp -and -not (Test-ClmStampSteady $clmStamp)
'@

function Add-ClmGuardedLoad {
  param([string]$Script)
  return $Script.Replace("<ClmGuardedLoad>", $script:ClmGuardedLoad)
}
