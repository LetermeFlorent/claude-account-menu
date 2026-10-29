$script:ClmModuleDir = $PSScriptRoot

function Import-ClmModule {
  param([string[]]$ClmImportNames)
  foreach ($ClmImportName in $ClmImportNames) {
    if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add($ClmImportName)) { . (Join-Path $script:ClmModuleDir ($ClmImportName + ".ps1")) }
  }
  Remove-Variable ClmImportNames, ClmImportName -ErrorAction Ignore
}
