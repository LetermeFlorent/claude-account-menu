$script:SealMagic = [byte[]]@(0x43, 0x4C, 0x4D, 0x53, 0x01)
$script:SealIvSize = 16
$script:SealMacSize = 32
$script:SealRefused = "fichier refuse : en clair, modifie ou chiffre avec une autre phrase"
$script:SyncKeyMinIterations = 600000
$script:SyncKeyIterations = 600000

function New-SyncRandomBytes {
  param([int]$Count)
  $out = New-Object byte[] $Count
  $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
  try { $rng.GetBytes($out) } finally { $rng.Dispose() }
  return ,$out
}

function Get-SyncHmac {
  param([byte[]]$Key, [byte[]]$Data)
  $h = New-Object Security.Cryptography.HMACSHA256 (, $Key)
  try { return ,$h.ComputeHash($Data) } finally { $h.Dispose() }
}

function ConvertTo-SyncHex {
  param([byte[]]$Bytes)
  return [BitConverter]::ToString($Bytes).Replace("-", "").ToLowerInvariant()
}

function Test-SyncBytesEqual {
  param([byte[]]$A, [byte[]]$B)
  if ($null -eq $A -or $null -eq $B -or $A.Length -ne $B.Length) { return $false }
  $diff = 0
  for ($i = 0; $i -lt $A.Length; $i++) { $diff = $diff -bor ($A[$i] -bxor $B[$i]) }
  return $diff -eq 0
}

function Get-SyncSubKey {
  param([byte[]]$Master, [string]$Label)
  return ,(Get-SyncHmac $Master ([Text.Encoding]::ASCII.GetBytes($Label)))
}

function New-SyncKeys {
  param([byte[]]$Master, [byte[]]$Salt, [int]$Iterations)
  $keys = @{ Master = $Master; Salt = $Salt; Iterations = $Iterations }
  $keys.Enc = Get-SyncSubKey $Master "clm-sync-enc"
  $keys.Mac = Get-SyncSubKey $Master "clm-sync-mac"
  $keys.Tag = Get-SyncSubKey $Master "clm-sync-tag"
  $keys.Check = ConvertTo-SyncHex (Get-SyncSubKey $keys.Mac "clm-sync-check")
  $keys.Id = $keys.Check.Substring(0, 16)
  return $keys
}

function ConvertTo-SyncMaster {
  param([string]$Passphrase, [byte[]]$Salt, [int]$Iterations)
  $pass = [Text.Encoding]::UTF8.GetBytes($Passphrase)
  $kdf = New-Object Security.Cryptography.Rfc2898DeriveBytes $pass, $Salt, $Iterations, ([Security.Cryptography.HashAlgorithmName]::SHA256)
  try { return ,$kdf.GetBytes(32) } finally { $kdf.Dispose(); [Array]::Clear($pass, 0, $pass.Length) }
}

function New-SyncKeysFromPass {
  param([string]$Passphrase, [byte[]]$Salt, [int]$Iterations)
  return New-SyncKeys (ConvertTo-SyncMaster $Passphrase $Salt $Iterations) $Salt $Iterations
}

function New-SyncAes {
  param([byte[]]$Key)
  $aes = [Security.Cryptography.Aes]::Create()
  $aes.KeySize = 256
  $aes.Key = $Key
  return $aes
}

function Get-SealMac {
  param($Keys, [string]$Seal, [byte[]]$Data, [int]$Count)
  $path = [Text.Encoding]::UTF8.GetBytes($Seal)
  $len = [BitConverter]::GetBytes([int]$path.Length)
  if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($len) }
  $ms = New-Object IO.MemoryStream
  $ms.Write($len, 0, 4)
  $ms.Write($path, 0, $path.Length)
  $ms.Write($Data, 0, $Count)
  return ,(Get-SyncHmac $Keys.Mac $ms.ToArray())
}

function New-SealRefusal {
  return New-Object Security.Cryptography.CryptographicException $script:SealRefused
}

function Test-SealRefusal {
  param($ErrorRecord)
  if ($null -eq $ErrorRecord) { return $false }
  return $ErrorRecord.Exception.GetBaseException() -is [Security.Cryptography.CryptographicException]
}

function Protect-SyncBytes {
  param($Keys, [string]$Seal, [byte[]]$Plain)
  $iv = New-SyncRandomBytes $script:SealIvSize
  $aes = New-SyncAes $Keys.Enc
  try { $ct = $aes.CreateEncryptor($Keys.Enc, $iv).TransformFinalBlock($Plain, 0, $Plain.Length) } finally { $aes.Dispose() }
  $ms = New-Object IO.MemoryStream
  foreach ($part in @($script:SealMagic, $iv, $ct)) { $ms.Write($part, 0, $part.Length) }
  $body = $ms.ToArray()
  $mac = Get-SealMac $Keys $Seal $body $body.Length
  $ms.Write($mac, 0, $mac.Length)
  return ,$ms.ToArray()
}

function Unprotect-SyncBytes {
  param($Keys, [string]$Seal, [byte[]]$Data)
  $head = $script:SealMagic.Length
  $ctLen = $Data.Length - $head - $script:SealIvSize - $script:SealMacSize
  if ($ctLen -lt 16 -or $ctLen % 16 -ne 0) { throw (New-SealRefusal) }
  if (-not (Test-SyncBytesEqual $script:SealMagic ([byte[]]$Data[0..($head - 1)]))) { throw (New-SealRefusal) }
  $bodyLen = $Data.Length - $script:SealMacSize
  $mac = New-Object byte[] $script:SealMacSize
  [Array]::Copy($Data, $bodyLen, $mac, 0, $script:SealMacSize)
  if (-not (Test-SyncBytesEqual (Get-SealMac $Keys $Seal $Data $bodyLen) $mac)) { throw (New-SealRefusal) }
  $iv = New-Object byte[] $script:SealIvSize
  [Array]::Copy($Data, $head, $iv, 0, $script:SealIvSize)
  $aes = New-SyncAes $Keys.Enc
  try { return ,$aes.CreateDecryptor($Keys.Enc, $iv).TransformFinalBlock($Data, $head + $script:SealIvSize, $ctLen) } finally { $aes.Dispose() }
}

function Invoke-TagCipher {
  param($Keys, [byte[]]$Block, [bool]$Encrypt)
  $aes = New-SyncAes $Keys.Tag
  $aes.Mode = [Security.Cryptography.CipherMode]::ECB
  $aes.Padding = [Security.Cryptography.PaddingMode]::None
  try {
    if ($Encrypt) { $t = $aes.CreateEncryptor() } else { $t = $aes.CreateDecryptor() }
    return ,$t.TransformFinalBlock($Block, 0, 16)
  } finally { $aes.Dispose() }
}

function ConvertFrom-SyncHex {
  param([string]$Hex)
  $out = New-Object byte[] ($Hex.Length / 2)
  for ($i = 0; $i -lt $out.Length; $i++) { $out[$i] = [Convert]::ToByte($Hex.Substring($i * 2, 2), 16) }
  return ,$out
}

function Protect-ContentMd5 {
  param($Keys, [string]$Md5)
  return $Keys.Id + (ConvertTo-SyncHex (Invoke-TagCipher $Keys (ConvertFrom-SyncHex $Md5) $true))
}

function Unprotect-ContentMd5 {
  param($Keys, [string]$Tag)
  if ($Tag -notmatch '^[0-9a-f]{48}$' -or -not $Tag.StartsWith($Keys.Id, [StringComparison]::Ordinal)) { return "" }
  return ConvertTo-SyncHex (Invoke-TagCipher $Keys (ConvertFrom-SyncHex $Tag.Substring(16)) $false)
}
