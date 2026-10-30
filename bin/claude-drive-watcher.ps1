if (-not (Test-Path Function:\Import-ClmModule)) { . (Join-Path $PSScriptRoot "claude-import.ps1") }
. Import-ClmModule claude-drive-watcher
