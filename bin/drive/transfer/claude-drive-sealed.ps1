. Import-ClmModule claude-sync-keyfile
$script:SealedPrefix = "clm-enc/"
$script:SealedFilesArea = "files/"
$script:SealedTagShape = New-Object regex '^[0-9a-f]{48}$', ([Text.RegularExpressions.RegexOptions]"IgnoreCase, CultureInvariant")
$script:SealedTagIdHex = 16
$script:SealedTagHalfHex = 16
$script:SealedTagHalfBytes = 8
$script:SealedTagBytes = 16

function Get-BytesMd5 {
  param([byte[]]$Bytes)
  $md5 = [Security.Cryptography.MD5]::Create()
  try { return ConvertTo-SyncHex ($md5.ComputeHash($Bytes)) } finally { $md5.Dispose() }
}

function Send-SealedText {
  param($Item)
  $bytes = [Text.Encoding]::UTF8.GetBytes([string]$Item.Text)
  return Send-DriveContent ([string]$Item.FolderId) ([string]$Item.Name) (Protect-SyncBytes $Item.Keys ([string]$Item.Seal) $bytes) $Item.Props ([string]$Item.Id)
}

function Get-SealedText {
  param([string]$Id, [string]$Seal, $Keys)
  return [Text.Encoding]::UTF8.GetString((Unprotect-SyncBytes $Keys $Seal (Get-DriveBytes $Id)))
}

function New-SealedProps {
  param($Keys, [string]$Md5, $Props)
  $p = @{ h = (Protect-ContentMd5 $Keys $Md5); k = $Keys.Id }
  foreach ($k in $Props.Keys) { $p[$k] = $Props[$k] }
  return $p
}

function Send-SealedFile {
  param($Item)
  $bytes = [byte[]]$Item.Bytes
  $rel = [string]$Item.Rel
  $md5 = Get-BytesMd5 $bytes
  $p = New-SealedProps $Item.Keys $md5 $Item.Props
  $r = Send-DriveContent ([string]$Item.FolderId) ($script:SealedPrefix + $rel) (Protect-SyncBytes $Item.Keys ($script:SealedFilesArea + $rel) $bytes) $p ([string]$Item.Id)
  return @{ Id = $r.Id; Md5 = $md5 }
}

function Unprotect-ListingMd5s {
  param($Keys, [string[]]$Tags)
  $out = New-Object string[] $Tags.Length
  $at = New-Object 'System.Collections.Generic.List[int]'
  for ($i = 0; $i -lt $Tags.Length; $i++) {
    $out[$i] = ""
    if ($script:SealedTagShape.IsMatch($Tags[$i]) -and $Tags[$i].StartsWith($Keys.Id, [StringComparison]::Ordinal)) { $at.Add($i) }
  }
  if ($at.Count -eq 0) { return ,$out }
  $block = New-Object byte[] ($at.Count * $script:SealedTagBytes)
  $o = 0
  foreach ($i in $at) {
    foreach ($start in $script:SealedTagIdHex, ($script:SealedTagIdHex + $script:SealedTagHalfHex)) {
      $half = [BitConverter]::GetBytes([Convert]::ToUInt64($Tags[$i].Substring($start, $script:SealedTagHalfHex), 16))
      if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($half) }
      [Array]::Copy($half, 0, $block, $o, $script:SealedTagHalfBytes)
      $o += $script:SealedTagHalfBytes
    }
  }
  $hex = ConvertTo-SyncHex (Invoke-TagCipher $Keys $block $false)
  $width = 2 * $script:SealedTagBytes
  for ($j = 0; $j -lt $at.Count; $j++) { $out[$at[$j]] = $hex.Substring($j * $width, $width) }
  return ,$out
}

function ConvertFrom-SealedListing {
  param($Listing, $Keys)
  $files = New-PathMap
  $twins = New-Object 'System.Collections.Generic.List[string]'
  $sealed = New-Object 'System.Collections.Generic.List[string]'
  foreach ($k in $Listing.Keys) {
    if ($k.StartsWith($script:SealedPrefix, [StringComparison]::Ordinal)) { $sealed.Add($k); continue }
    $e = $Listing[$k]
    $files[$k] = @{ Id = $e.Id; Name = $k; Md5 = [string]$e.Md5; M = $e.M; Pc = $e.Pc; Exp = $e.Exp; Props = $e.Props; Raw = [string]$e.Md5; Plain = $true; SealedId = ""; PlainId = [string]$e.Id }
  }
  $md5s = Unprotect-ListingMd5s $Keys ([string[]]@(foreach ($k in $sealed) { [string]$Listing[$k].Md5 }))
  for ($j = 0; $j -lt $sealed.Count; $j++) {
    $k = $sealed[$j]
    $e = $Listing[$k]
    $rel = $k.Substring($script:SealedPrefix.Length)
    $md5 = $md5s[$j]
    $plain = -not $md5
    if ($plain) { $md5 = [string]$e.Md5 }
    $old = $files[$rel]
    $m = @{ Id = $e.Id; Name = $rel; Md5 = $md5; M = $e.M; Pc = $e.Pc; Exp = $e.Exp; Props = $e.Props; Raw = [string]$e.Md5; Plain = $plain; SealedId = [string]$e.Id; PlainId = "" }
    if ($null -ne $old) { $m.PlainId = $old.PlainId }
    if ($null -ne $old -and -not $plain) { $twins.Add($old.PlainId) }
    $files[$rel] = $m
  }
  return @{ Files = $files; Twins = $twins.ToArray() }
}
