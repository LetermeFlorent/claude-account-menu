if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-sync-keyfile.ps1")) { . (Join-Path $PSScriptRoot "claude-sync-keyfile.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-drive-login.ps1")) { . (Join-Path $PSScriptRoot "claude-drive-login.ps1") }
$script:SyncPassMin = 12
$script:SyncPassShort = "phrase trop courte : 12 caracteres au moins"
$script:SyncPassDiffer = "les deux saisies different, rien n'est change"
$script:SyncPassWrong = "phrase de synchro incorrecte"

function Read-SyncPassText {
  param([string]$Prompt)
  $s = Read-Host -AsSecureString ("  " + $Prompt)
  $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr); $s.Dispose() }
}

function Read-NewSyncPass {
  $first = Read-SyncPassText "Nouvelle phrase de synchro, 12 caracteres au moins, la meme sur chaque PC"
  if ($first.Length -lt $script:SyncPassMin) { throw $script:SyncPassShort }
  if ((Read-SyncPassText "La meme phrase encore une fois") -cne $first) { throw $script:SyncPassDiffer }
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
    return "phrase de synchro creee : la saisir aussi sur les autres PC"
  }
  $params = Read-SyncKeyParams $entry
  $keys = New-SyncKeysFromPass (Read-SyncPassText "Phrase de synchro de ce Drive") $params.Salt $params.Iterations
  if (-not (Test-SyncCheckEqual $keys.Check $params.Check)) { throw $script:SyncPassWrong }
  Save-SyncKeys $keys
  return "phrase de synchro enregistree sur ce PC"
}

function Reset-SyncPassphrase {
  $folders = Get-DriveFolders
  $entry = Get-SyncKeyFile $folders
  $id = ""
  if ($null -ne $entry) { $id = [string]$entry.Id }
  New-SyncKeysForDrive $folders $id
  return "phrase de synchro changee : ce PC renvoie ses fichiers, les autres PC doivent saisir la nouvelle"
}

function Clear-SyncPassphrase {
  Remove-SyncKeys
  return "phrase de synchro oubliee sur ce PC, synchro Drive arretee ici"
}

function Invoke-DriveSetup {
  $msg = ""
  if (-not (Test-DriveConnected)) { $msg = Invoke-DriveLogin }
  if ((Test-DriveConnected) -and -not (Test-SyncKeyStored)) { $msg = Set-SyncPassphrase }
  return $msg
}
