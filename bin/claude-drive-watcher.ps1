if (-not (Test-Path Function:\Import-ClmModule)) { . (Join-Path $PSScriptRoot "claude-import.ps1") }
if ($null -eq $script:ClmOnce) { $script:ClmOnce = New-Object "System.Collections.Generic.HashSet[string]" }
. Import-ClmModule claude-drive-watcher
