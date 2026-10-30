. Import-ClmModule claude-sync-crypto, claude-drive-transfer-seal

function Copy-SealedRange {
  param($From, [long]$Count, $To, $Mac)
  $buffer = New-Object byte[] $script:SealPieceSize
  while ($Count -gt 0) {
    $n = $From.Read($buffer, 0, [int][Math]::Min([long]$buffer.Length, $Count))
    if ($n -le 0) { throw (New-SealRefusal) }
    if ($null -ne $Mac) { $null = $Mac.TransformBlock($buffer, 0, $n, $null, 0) }
    if ($null -ne $To) { $To.Write($buffer, 0, $n) }
    $Count -= $n
  }
}

function Test-SealedFile {
  param($Keys, [string]$Seal, $File)
  $cipherLength = $File.Length - $script:SealMagic.Length - $script:SealIvSize - $script:SealMacSize
  if ($cipherLength -lt 16 -or $cipherLength % 16 -ne 0) { return $false }
  $head = New-Object byte[] $script:SealMagic.Length
  Read-PlainPiece $File $head $head.Length
  if (-not (Test-SyncBytesEqual $script:SealMagic $head)) { return $false }
  $mac = New-Object Security.Cryptography.HMACSHA256 (, $Keys.Mac)
  try {
    Add-SealMac $mac (Get-SealPrefix $Seal)
    Add-SealMac $mac $head
    Copy-SealedRange $File ($File.Length - $head.Length - $script:SealMacSize) $null $mac
    $null = $mac.TransformFinalBlock((New-Object byte[] 0), 0, 0)
    $tag = New-Object byte[] $script:SealMacSize
    Read-PlainPiece $File $tag $tag.Length
    return Test-SyncBytesEqual $mac.Hash $tag
  } finally { $mac.Dispose() }
}

function Write-OpenedFile {
  param($Keys, [byte[]]$Iv, $File, [long]$Count, [string]$To)
  $aes = New-SyncAes $Keys.Enc
  $out = [IO.File]::Open($To, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::None)
  try {
    $crypto = New-Object Security.Cryptography.CryptoStream -ArgumentList $out, $aes.CreateDecryptor($Keys.Enc, $Iv), ([Security.Cryptography.CryptoStreamMode]::Write)
    try {
      Copy-SealedRange $File $Count $crypto $null
      $crypto.FlushFinalBlock()
    } finally { $crypto.Dispose() }
  } finally { $out.Dispose(); $aes.Dispose() }
}

function Expand-SealedFile {
  param($Keys, [string]$Seal, [string]$From, [string]$To)
  $file = [IO.File]::OpenRead($From)
  try {
    if (-not (Test-SealedFile $Keys $Seal $file)) { throw (New-SealRefusal) }
    $file.Position = $script:SealMagic.Length
    $iv = New-Object byte[] $script:SealIvSize
    Read-PlainPiece $file $iv $iv.Length
    Write-OpenedFile $Keys $iv $file ($file.Length - $file.Position - $script:SealMacSize) $To
  } finally { $file.Dispose() }
}
