if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-sync-keyfile.ps1")) { . (Join-Path $PSScriptRoot "claude-sync-keyfile.ps1") }
$script:SealedPrefix = "clm-enc/"
$script:SealedFilesArea = "files/"

function Get-BytesMd5 {
  param([byte[]]$Bytes)
  $md5 = [Security.Cryptography.MD5]::Create()
  try { return ConvertTo-SyncHex ($md5.ComputeHash($Bytes)) } finally { $md5.Dispose() }
}

function Send-SealedText {
  param([string]$FolderId, [string]$Name, [string]$Seal, [string]$Text, $Props, [string]$Id, $Keys)
  return Send-DriveContent $FolderId $Name (Protect-SyncBytes $Keys $Seal ([Text.Encoding]::UTF8.GetBytes($Text))) $Props $Id
}

function Get-SealedText {
  param([string]$Id, [string]$Seal, $Keys)
  return [Text.Encoding]::UTF8.GetString((Unprotect-SyncBytes $Keys $Seal (Get-DriveBytes $Id)))
}

function Send-SealedFile {
  param([string]$FolderId, [string]$Rel, [byte[]]$Bytes, $Props, [string]$Id, $Keys)
  $md5 = Get-BytesMd5 $Bytes
  $p = @{ h = (Protect-ContentMd5 $Keys $md5); k = $Keys.Id }
  foreach ($k in $Props.Keys) { $p[$k] = $Props[$k] }
  $r = Send-DriveContent $FolderId ($script:SealedPrefix + $Rel) (Protect-SyncBytes $Keys ($script:SealedFilesArea + $Rel) $Bytes) $p $Id
  return @{ Id = $r.Id; Md5 = $md5 }
}

function New-MergedEntry {
  param($Entry, [string]$Rel, [string]$Md5, [bool]$Plain)
  return @{ Id = $Entry.Id; Name = $Rel; Md5 = $Md5; M = $Entry.M; Pc = $Entry.Pc; Exp = $Entry.Exp; Props = $Entry.Props; Plain = $Plain; SealedId = ""; PlainId = "" }
}

function ConvertFrom-SealedListing {
  param($Listing, $Keys)
  $files = New-PathMap
  $twins = New-Object 'System.Collections.Generic.List[string]'
  $sealed = New-Object 'System.Collections.Generic.List[string]'
  foreach ($k in $Listing.Keys) {
    if ($k.StartsWith($script:SealedPrefix, [StringComparison]::Ordinal)) { $sealed.Add($k); continue }
    $e = $Listing[$k]
    $files[$k] = New-MergedEntry $e $k ([string]$e.Md5) $true
    $files[$k].PlainId = [string]$e.Id
  }
  foreach ($k in $sealed) {
    $e = $Listing[$k]
    $rel = $k.Substring($script:SealedPrefix.Length)
    $md5 = Unprotect-ContentMd5 $Keys ([string]$e.Md5)
    $plain = -not $md5
    if ($plain) { $md5 = [string]$e.Md5 }
    $old = $files[$rel]
    $m = New-MergedEntry $e $rel $md5 $plain
    $m.SealedId = [string]$e.Id
    if ($null -ne $old) { $m.PlainId = $old.PlainId }
    if ($null -ne $old -and -not $plain) { $twins.Add($old.PlainId) }
    $files[$rel] = $m
  }
  return @{ Files = $files; Twins = $twins.ToArray() }
}
