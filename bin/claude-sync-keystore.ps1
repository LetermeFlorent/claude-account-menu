. Import-ClmModule claude-sync-crypto, claude-keychain, claude-file-io, claude-state
$script:SyncKeyStorePath = Get-StatePath "sync-key"
if ($null -eq $script:SyncKeyStoreOs) { $script:SyncKeyStoreOs = $script:OsName }
$script:SyncKeyService = "clm-sync-key"
$script:SyncKeyAccount = "clm"
$script:SyncKeyMissing = "phrase de synchro absente sur ce PC : la saisir par y dans le menu ou clm --sync-key"
$script:SyncKeyBroken = "cle de synchro de ce PC illisible : clm --sync-key-forget puis clm --sync-key"

function ConvertTo-SyncKeyRecord {
  param($Keys)
  $record = [ordered]@{ v = 1; salt = [Convert]::ToBase64String($Keys.Salt); iterations = $Keys.Iterations; check = $Keys.Check; key = [Convert]::ToBase64String($Keys.Master) }
  return ConvertTo-Json $record -Compress
}

function ConvertFrom-SyncKeyRecord {
  param([string]$Text)
  try {
    $r = $Text | ConvertFrom-Json
    $master = [Convert]::FromBase64String([string]$r.key)
    $keys = New-SyncKeys $master ([Convert]::FromBase64String([string]$r.salt)) ([int]$r.iterations)
  } catch { throw $script:SyncKeyBroken }
  $same = Test-SyncBytesEqual ([Text.Encoding]::ASCII.GetBytes($keys.Check)) ([Text.Encoding]::ASCII.GetBytes([string]$r.check))
  if ($master.Length -ne 32 -or -not $same) { throw $script:SyncKeyBroken }
  return $keys
}

function Protect-WindowsText {
  param([string]$Text)
  $s = New-Object Security.SecureString
  try {
    foreach ($c in $Text.ToCharArray()) { $s.AppendChar($c) }
    return ConvertFrom-SecureString $s
  } finally { $s.Dispose() }
}

function Unprotect-WindowsText {
  param([string]$Blob)
  $s = ConvertTo-SecureString $Blob
  $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr); $s.Dispose() }
}

function Write-SyncKeyText {
  param([string]$Text)
  if ($script:SyncKeyStoreOs -eq "MacOS") {
    Invoke-SecurityBatch @(ConvertTo-KeychainLine $script:SyncKeyService $script:SyncKeyAccount $Text)
    if ((Read-SyncKeyText) -cne $Text) { throw "trousseau : ecriture refusee" }
    return
  }
  if ($script:SyncKeyStoreOs -eq "Windows") { Write-TextFileAtomic $script:SyncKeyStorePath (Protect-WindowsText $Text); return }
  Write-TextFileAtomic $script:SyncKeyStorePath $Text -Private
}

function Read-SyncKeyText {
  if ($script:SyncKeyStoreOs -eq "MacOS") { return Read-KeychainItem $script:SyncKeyService $script:SyncKeyAccount }
  if (-not [IO.File]::Exists($script:SyncKeyStorePath)) { return $null }
  $text = (Read-SharedText $script:SyncKeyStorePath).Trim()
  if ($script:SyncKeyStoreOs -ne "Windows") { return $text }
  try { return Unprotect-WindowsText $text } catch { throw $script:SyncKeyBroken }
}

function Save-SyncKeys {
  param($Keys)
  Write-SyncKeyText (ConvertTo-SyncKeyRecord $Keys)
}

function Get-SyncKeys {
  $text = Read-SyncKeyText
  if (-not $text) { throw $script:SyncKeyMissing }
  return ConvertFrom-SyncKeyRecord $text
}

function Test-SyncKeyStored {
  try { $null = Get-SyncKeys } catch { return $false }
  return $true
}

function Remove-SyncKeys {
  if ($script:SyncKeyStoreOs -eq "MacOS") { Remove-KeychainItems $script:SyncKeyService @($script:SyncKeyAccount); return }
  if ([IO.File]::Exists($script:SyncKeyStorePath)) { [IO.File]::Delete($script:SyncKeyStorePath) }
}
