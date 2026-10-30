$script:ClmModuleDir = $PSScriptRoot
$script:ClmModuleFolders = @("drive/core", "drive/transfer", "drive/sync", "drive/data", "drive/watch", "drive/session", "menu/startup", "menu/view", "menu/loop", "menu/manage", "ui/terminal", "ui/color", "ui/render", "ui/display", "sync/core", "sync/crypto", "sync/mcp", "web/actions", "web/server", "usage", "update", "self", "cli", "accounts", "core", "machine", "backup", "statusline")
$script:ClmModulePaths = $null
$script:ClmInstallingStamp = "installing"
$script:ClmInstallStaleSeconds = 120

function Get-ClmModulePaths {
  $paths = @{}
  foreach ($folder in @($script:ClmModuleFolders) + @("")) {
    $dir = [IO.Path]::Combine($script:ClmModuleDir, $folder.Replace("/", [string][IO.Path]::DirectorySeparatorChar))
    if (-not [IO.Directory]::Exists($dir)) { continue }
    foreach ($file in [IO.Directory]::GetFiles($dir, "*.ps1") | Where-Object { $_.EndsWith(".ps1", [StringComparison]::OrdinalIgnoreCase) }) {
      $name = [IO.Path]::GetFileNameWithoutExtension($file)
      if (-not $paths.ContainsKey($name)) { $paths[$name] = $file }
    }
  }
  return $paths
}

function Get-ClmModulePath {
  param([string]$Name)
  if ($null -eq $script:ClmModulePaths) { $script:ClmModulePaths = Get-ClmModulePaths }
  $path = $script:ClmModulePaths[$Name]
  if ($null -eq $path) { $path = Join-Path $script:ClmModuleDir ($Name + ".ps1") }
  return $path
}

function Import-ClmModule {
  param([string[]]$ClmImportNames)
  try {
    foreach ($ClmImportName in $ClmImportNames) {
      if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add($ClmImportName)) {
        . (Get-ClmModulePath $ClmImportName)
      }
    }
  } finally {
    Remove-Variable ClmImportNames, ClmImportName -ErrorAction Ignore
  }
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
$script:ClmOnce = New-Object "System.Collections.Generic.HashSet[string]"
$clmRoot = Split-Path -Parent $Source
while ($clmRoot -and -not [IO.File]::Exists([IO.Path]::Combine($clmRoot, "claude-import.ps1"))) { $clmRoot = Split-Path -Parent $clmRoot }
$clmEntry = [IO.Path]::Combine("" + $clmRoot, "claude-import.ps1")
$clmStamp = $null
if ([IO.File]::Exists($clmEntry)) { . $clmEntry; if (Test-Path Function:\Read-ClmStamp) { $clmStamp = Read-ClmStamp } }
try { if ($clmStamp -cne "installing") { . $Source } } catch { if ($null -eq $clmStamp -or (Test-ClmStampSteady $clmStamp)) { throw } }
$clmReplaced = $null -ne $clmStamp -and -not (Test-ClmStampSteady $clmStamp)
'@

function Add-ClmGuardedLoad {
  param([string]$Script)
  return $Script.Replace("<ClmGuardedLoad>", $script:ClmGuardedLoad)
}
