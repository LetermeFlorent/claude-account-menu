. Import-ClmModule claude-state, claude-file-io, claude-machine-lock, claude-text
$script:BackupKeyName = "backup-key"
$script:BackupKeyLock = "backup-key"
$script:BackupKeyWaitMs = 30000
$script:BackupKeyBytes = 32

function Read-BackupKey {
  $path = Get-StatePath $script:BackupKeyName
  if (-not [IO.File]::Exists($path)) { return $null }
  try { $key = [Convert]::FromBase64String((Read-SharedText $path).Trim()) } catch [FormatException] { return $null }
  if ($key.Length -lt $script:BackupKeyBytes) { return $null }
  return ,$key
}

function New-BackupKey {
  $key = New-Object byte[] $script:BackupKeyBytes
  $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
  try { $rng.GetBytes($key) } finally { $rng.Dispose() }
  Write-TextFileAtomic (Get-StatePath $script:BackupKeyName) ([Convert]::ToBase64String($key)) -Private
  return ,$key
}

function Get-BackupKey {
  $key = Read-BackupKey
  if ($null -ne $key) { return ,$key }
  $lock = Open-MachineLock $script:BackupKeyLock $script:BackupKeyWaitMs
  try {
    $key = Read-BackupKey
    if ($null -ne $key) { return ,$key }
    if ($null -eq $lock) { throw (Get-ClmText "backup.key.busy") }
    return ,(New-BackupKey)
  } finally { Close-MachineLock $lock }
}
