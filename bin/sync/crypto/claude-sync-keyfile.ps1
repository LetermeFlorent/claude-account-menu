. Import-ClmModule claude-sync-keystore, claude-drive-transfer, claude-drive-folders, claude-text
$script:SyncKeyFileName = "clm-key.json"
$script:SyncKeyFileVersion = "1"

function Get-SyncKeyFile {
  param($Folders)
  return (Get-DriveListing $Folders.Root)[$script:SyncKeyFileName]
}

function Read-SyncKeyParams {
  param($Entry)
  $p = $Entry.Props
  $iterations = 0
  $salt = $null
  try { $salt = [Convert]::FromBase64String([string]$p["salt"]) } catch { throw (Get-ClmText "sync.key.weak") }
  $ok = [string]$p["v"] -eq $script:SyncKeyFileVersion -and [int]::TryParse([string]$p["iterations"], [ref]$iterations)
  if (-not $ok -or $iterations -lt $script:SyncKeyMinIterations -or $salt.Length -ne 16 -or [string]$p["check"] -cnotmatch '^[0-9a-f]{64}$') { throw (Get-ClmText "sync.key.weak") }
  return @{ Salt = $salt; Iterations = $iterations; Check = [string]$p["check"]; Id = [string]$Entry.Id }
}

function Publish-SyncKeyFile {
  param($Folders, $Keys, [string]$Id)
  $props = [ordered]@{ v = $script:SyncKeyFileVersion; salt = [Convert]::ToBase64String($Keys.Salt); iterations = ("" + $Keys.Iterations); check = $Keys.Check }
  $text = (ConvertTo-Json $props -Compress) + "`n"
  $null = Send-DriveContent $Folders.Root $script:SyncKeyFileName ([Text.Encoding]::UTF8.GetBytes($text)) $props $Id
}

function Test-SyncCheckEqual {
  param([string]$A, [string]$B)
  return Test-SyncBytesEqual ([Text.Encoding]::ASCII.GetBytes($A)) ([Text.Encoding]::ASCII.GetBytes($B))
}

function Assert-SyncKeysMatch {
  param($Folders, $Keys)
  $entry = Get-SyncKeyFile $Folders
  if ($null -eq $entry) { Publish-SyncKeyFile $Folders $Keys ""; return }
  if (-not (Test-SyncCheckEqual ([string]$entry.Props["check"]) $Keys.Check)) { throw (Get-ClmText "sync.key.changed") }
}
