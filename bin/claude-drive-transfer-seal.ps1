. Import-ClmModule claude-sync-crypto
$script:SealPieceSize = 64KB
$script:SealChanged = "fichier modifie pendant l'envoi"

function Get-SealedLength {
  param([long]$PlainLength)
  return [long]($script:SealMagic.Length + $script:SealIvSize + 16 * ([Math]::Floor($PlainLength / 16) + 1) + $script:SealMacSize)
}

function Get-SealPrefix {
  param([string]$Seal)
  $path = [Text.Encoding]::UTF8.GetBytes($Seal)
  $len = [BitConverter]::GetBytes([int]$path.Length)
  if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($len) }
  return ,[byte[]]($len + $path)
}

function Add-SealMac {
  param($Mac, [byte[]]$Bytes)
  $null = $Mac.TransformBlock($Bytes, 0, $Bytes.Length, $null, 0)
}

function Initialize-SealedSource {
  param($Source, $Keys, [string]$Seal)
  $iv = New-SyncRandomBytes $script:SealIvSize
  $head = [byte[]]($script:SealMagic + $iv)
  $Source.Length = Get-SealedLength $Source.File.Length
  $Source.Left = [long]$Source.File.Length
  $Source.Read = "Read-SealedSource"
  $Source.Aes = New-SyncAes $Keys.Enc
  $Source.Encryptor = $Source.Aes.CreateEncryptor($Keys.Enc, $iv)
  $Source.Mac = New-Object Security.Cryptography.HMACSHA256 (, $Keys.Mac)
  Add-SealMac $Source.Mac (Get-SealPrefix $Seal)
  Add-SealMac $Source.Mac $head
  $Source.Plain = New-Object byte[] $script:SealPieceSize
  $Source.Piece = $head
  $Source.PieceAt = 0
  $Source.Ended = $false
  $Source.Done = $false
}

function Open-SealedSource {
  param($Keys, [string]$Seal, [string]$Path)
  $source = @{ File = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete) }
  try { Initialize-SealedSource $source $Keys $Seal } catch { Close-SealedSource $source; throw }
  return $source
}

function Read-PlainPiece {
  param($File, [byte[]]$Buffer, [int]$Count)
  $done = 0
  while ($done -lt $Count) {
    $n = $File.Read($Buffer, $done, $Count - $done)
    if ($n -le 0) { throw $script:SealChanged }
    $done += $n
  }
}

function Get-SealedPiece {
  param($Source)
  if ($Source.Ended) {
    $null = $Source.Mac.TransformFinalBlock((New-Object byte[] 0), 0, 0)
    $Source.Done = $true
    return ,$Source.Mac.Hash
  }
  $size = [int][Math]::Min([long]$Source.Plain.Length, $Source.Left)
  Read-PlainPiece $Source.File $Source.Plain $size
  $Source.Left -= $size
  if ($Source.Left -eq 0) {
    $piece = $Source.Encryptor.TransformFinalBlock($Source.Plain, 0, $size)
    $Source.Ended = $true
  } else {
    $piece = New-Object byte[] $size
    $made = $Source.Encryptor.TransformBlock($Source.Plain, 0, $size, $piece, 0)
    if ($made -lt $size) { [Array]::Resize([ref]$piece, $made) }
  }
  Add-SealMac $Source.Mac $piece
  return ,$piece
}

function Read-SealedSource {
  param($Source, [byte[]]$Buffer, [int]$Offset, [int]$Count)
  $done = 0
  while ($done -lt $Count) {
    if ($Source.PieceAt -ge $Source.Piece.Length) {
      if ($Source.Done) { break }
      $Source.Piece = Get-SealedPiece $Source
      $Source.PieceAt = 0
      continue
    }
    $n = [Math]::Min($Count - $done, $Source.Piece.Length - $Source.PieceAt)
    [Array]::Copy($Source.Piece, $Source.PieceAt, $Buffer, $Offset + $done, $n)
    $Source.PieceAt += $n
    $done += $n
  }
  return $done
}

function Close-SealedSource {
  param($Source)
  foreach ($part in @($Source.Encryptor, $Source.Mac, $Source.Aes, $Source.File)) {
    if ($null -ne $part) { $part.Dispose() }
  }
}
