. Import-ClmModule claude-sync-keyfile, claude-drive-login, claude-text
$script:SyncPassMin = 12

function Read-SyncPassText {
  param([string]$Prompt)
  $s = Read-Host -AsSecureString ("  " + $Prompt)
  $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr); $s.Dispose() }
}

function Read-NewSyncPass {
  $first = Read-SyncPassText (Get-ClmText "sync.pass.askNew")
  if ($first.Length -lt $script:SyncPassMin) { throw (Get-ClmText "sync.pass.short") }
  if ((Read-SyncPassText (Get-ClmText "sync.pass.askAgain")) -cne $first) { throw (Get-ClmText "sync.pass.differ") }
  return $first
}

function New-SyncKeysForDrive {
  param($Folders, [string]$Id)
  $keys = New-SyncKeysFromPass (Read-NewSyncPass) (New-SyncRandomBytes 16) $script:SyncKeyIterations
  Publish-SyncKeyFile $Folders $keys $Id
  Save-SyncKeys $keys
}

function Set-SyncPassphrase {
  $folders = Get-DriveFolders
  $entry = Get-SyncKeyFile $folders
  if ($null -eq $entry) {
    New-SyncKeysForDrive $folders ""
    return Get-ClmText "sync.pass.created"
  }
  $params = Read-SyncKeyParams $entry
  $keys = New-SyncKeysFromPass (Read-SyncPassText (Get-ClmText "sync.pass.askDrive")) $params.Salt $params.Iterations
  if (-not (Test-SyncCheckEqual $keys.Check $params.Check)) { throw (Get-ClmText "sync.pass.wrong") }
  Save-SyncKeys $keys
  return Get-ClmText "sync.pass.saved"
}

function Reset-SyncPassphrase {
  $folders = Get-DriveFolders
  $entry = Get-SyncKeyFile $folders
  $id = ""
  if ($null -ne $entry) { $id = [string]$entry.Id }
  New-SyncKeysForDrive $folders $id
  return Get-ClmText "sync.pass.changed"
}

function Clear-SyncPassphrase {
  Remove-SyncKeys
  return Get-ClmText "sync.pass.forgotten"
}

function Invoke-DriveSetup {
  $msg = ""
  if (-not (Test-DriveConnected)) { $msg = Invoke-DriveLogin }
  if ((Test-DriveConnected) -and -not (Test-SyncKeyStored)) { $msg = Set-SyncPassphrase }
  return $msg
}
