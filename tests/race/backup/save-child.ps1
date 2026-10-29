param([string]$Bin, [string]$Lab, [string]$Dir, [string]$Downloads, [string]$Id, [string]$Mode)
$ErrorActionPreference = "Stop"
. (Join-Path $Lab "race-helpers.ps1")
. (Join-Path $Bin "claude-import.ps1")
. Import-ClmModule claude-accounts, claude-ui-progress, claude-menu-archive, claude-self-version, claude-menu-save

function Get-DownloadsDir { return $Downloads }

if ($Mode -eq "list") {
  foreach ($b in @(Get-Backups)) { "listed " + $b.Name }
  return
}

Initialize-Tar
Wait-RaceGate $Dir $Id
$saved = Save-Accounts
"result " + $Id + " " + ($saved -replace ' \(.*$', '')
