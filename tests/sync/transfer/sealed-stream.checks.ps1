. Import-ClmModule claude-drive-transfer-seal
class SealHttpFailure : Exception {
  $Response
  SealHttpFailure([string]$Message, $Response) : base($Message) { $this.Response = $Response }
}

. (Join-Path $bin "claude-drive-api.ps1"); $script:SealToken = ${function:Get-DriveToken}
$script:SealSavedChunk = $script:DriveChunkSize
$script:SealKeep = $true
$script:SealUp = New-Object IO.MemoryStream
$script:SealMeta = ""
$script:SealStartLen = ""
$script:SealMaxBody = 0
$script:SealBytesIn = 0
function Get-SealLiveBytes { [Runtime.GCSettings]::LargeObjectHeapCompactionMode = 'CompactOnce'; return [GC]::GetTotalMemory($true) }

function Get-DriveToken { param([switch]$Renew) return "tok" }
function Invoke-DriveWeb {
  param($Request)
  if ($Request.Method -eq "POST" -and $Request.Uri -like "*uploadType=resumable*") {
    $script:SealMeta = [Text.Encoding]::UTF8.GetString([byte[]]$Request.Body)
    $script:SealStartLen = [string]$Request.Headers["X-Upload-Content-Length"]
    return [PSCustomObject]@{ StatusCode = 200; Headers = @{ Location = "https://upload.example/s1" }; RawContentStream = (New-Object IO.MemoryStream) }
  }
  $m = [regex]::Match([string]$Request.Headers["Content-Range"], '^bytes (\d+)-(\d+)/(\d+)$')
  $len = $Request.Body.Length
  $script:SealBytesIn += $len
  if ($len -gt $script:SealMaxBody) { $script:SealMaxBody = $len }
  if ($script:SealKeep) { $script:SealUp.Write([byte[]]$Request.Body, 0, $len) }
  else {
    $mem = Get-SealLiveBytes
    if ($mem -gt $script:SealMaxMem) { $script:SealMaxMem = $mem }
  }
  $last = [long]$m.Groups[2].Value
  if ($last + 1 -lt [long]$m.Groups[3].Value) {
    $resp = [PSCustomObject]@{ StatusCode = 308; Headers = @{ Range = "bytes=0-" + $last } }
    throw [SealHttpFailure]::new("Le serveur distant a retourne une erreur : (308)", $resp)
  }
  $ok = New-Object IO.MemoryStream(, [Text.Encoding]::UTF8.GetBytes('{"id":"S1","md5Checksum":"x"}'))
  return [PSCustomObject]@{ StatusCode = 200; Headers = @{}; RawContentStream = $ok }
}
function New-SealPlain {
  param([int]$Length)
  $pattern = New-Object byte[] 4093
  for ($i = 0; $i -lt $pattern.Length; $i++) { $pattern[$i] = ($i * 7 + 3) % 251 }
  $bytes = New-Object byte[] $Length
  for ($at = 0; $at -lt $Length; $at += $pattern.Length) { [Array]::Copy($pattern, 0, $bytes, $at, [Math]::Min($pattern.Length, $Length - $at)) }
  return ,$bytes
}
function Read-SealAll {
  param($Source)
  $plan = @(1000, 70000, 7, 70000, 33333)
  $ms = New-Object IO.MemoryStream
  $step = 0
  while ($true) {
    $size = 65537
    if ($step -lt $plan.Count) { $size = $plan[$step] }
    $step++
    $buf = New-Object byte[] ($size + 3)
    $n = Read-SealedSource $Source $buf 3 $size
    if ($n -le 0) { break }
    $ms.Write($buf, 3, $n)
  }
  return ,$ms.ToArray()
}
function Get-SealRoundTrip {
  param([int]$Length, [string]$Name)
  $p = Join-Path $script:Sandbox $Name
  $plain = New-SealPlain $Length
  [IO.File]::WriteAllBytes($p, $plain)
  $src = Open-SealedSource $sealKeys "files/.claude/big.bin" $p
  try { $sealed = Read-SealAll $src } finally { Close-SealedSource $src }
  Remove-Item -LiteralPath $p -Force
  return @{ Plain = $plain; Sealed = $sealed; Length = $src.Length }
}
function Test-SameBytes {
  param([byte[]]$A, [byte[]]$B)
  return ($A.Length -eq $B.Length -and [Convert]::ToBase64String($A) -eq [Convert]::ToBase64String($B))
}
function Test-Deletable {
  param([string]$Path)
  try { Remove-Item -LiteralPath $Path -Force -ErrorAction Stop } catch { return $false }
  return -not [IO.File]::Exists($Path)
}

$sealKeys = New-SyncKeys ([byte[]](50..81)) ([byte[]](1..16)) 600000
$sealBig = 300001
$sealBigLen = 5 + 16 + 16 * (18750 + 1) + 32
$sealRt = Get-SealRoundTrip $sealBig "seal-round.bin"
Assert-Equal $sealBigLen $sealRt.Length "chiffrement en flux : longueur annoncee exacte"
Assert-Equal $sealBigLen $sealRt.Sealed.Length "chiffrement en flux : octets lus egaux a la longueur"
Assert-True (Test-SameBytes $sealRt.Plain (Unprotect-SyncBytes $sealKeys "files/.claude/big.bin" $sealRt.Sealed)) "chiffrement en flux : aller-retour"
Assert-Throws { Unprotect-SyncBytes $sealKeys "files/.claude/other.bin" $sealRt.Sealed } $script:SealRefused "chiffrement en flux : autre chemin refuse"

$sealRt = Get-SealRoundTrip 0 "seal-empty.bin"
Assert-True ($sealRt.Length -eq 69 -and $sealRt.Sealed.Length -eq 69) "chiffrement en flux : fichier vide, 69 octets"
Assert-Equal 0 (Unprotect-SyncBytes $sealKeys "files/.claude/big.bin" $sealRt.Sealed).Length "chiffrement en flux : fichier vide relu"
$sealRt = Get-SealRoundTrip 32 "seal-block.bin"
Assert-True ($sealRt.Length -eq (5 + 16 + 48 + 32) -and $sealRt.Sealed.Length -eq $sealRt.Length) "chiffrement en flux : multiple de bloc, longueur"
Assert-True (Test-SameBytes $sealRt.Plain (Unprotect-SyncBytes $sealKeys "files/.claude/big.bin" $sealRt.Sealed)) "chiffrement en flux : multiple de bloc, aller-retour"

$sealShrink = Join-Path $script:Sandbox "seal-shrink.bin"
[IO.File]::WriteAllBytes($sealShrink, (New-SealPlain 100000))
$sealSrc = Open-SealedSource $sealKeys "files/.claude/big.bin" $sealShrink
$sealBuf = New-Object byte[] 1000
$null = Read-SealedSource $sealSrc $sealBuf 0 1000
$sealFs = [IO.File]::Open($sealShrink, 'Open', 'ReadWrite', 'ReadWrite')
$sealFs.SetLength(10)
$sealFs.Dispose()
Assert-Throws { while ((Read-SealedSource $sealSrc $sealBuf 0 1000) -gt 0) { } } (Get-ClmText "drive.upload.source.changed") "chiffrement en flux : fichier raccourci refuse"
Close-SealedSource $sealSrc
Assert-True (Test-Deletable $sealShrink) "chiffrement en flux : fermeture libere le fichier"

$sealPath = Join-Path $script:Sandbox "seal-send.bin"
$sealPlain = New-SealPlain $sealBig
[IO.File]::WriteAllBytes($sealPath, $sealPlain)
$script:DriveChunkSize = 256KB
$script:SealKeep = $true
$sealSent = Send-SealedPath @{ FolderId = "folder1"; Rel = ".claude/big.bin"; Path = $sealPath; Props = @{}; Id = ""; Keys = $sealKeys }
$sealDoc = $script:SealMeta | ConvertFrom-Json
$sealMd5 = Get-FileMd5 $sealPath
Assert-Equal "clm-enc/.claude/big.bin" $sealDoc.name "envoi en flux : nom du Drive"
Assert-Equal ("" + $sealBigLen) $script:SealStartLen "envoi en flux : longueur annoncee au demarrage"
Assert-True (Test-SameBytes $sealPlain (Unprotect-SyncBytes $sealKeys "files/.claude/big.bin" $script:SealUp.ToArray())) "envoi en flux : octets recus rechiffres a l'identique"
Assert-Equal $sealMd5 $sealSent.Md5 "envoi en flux : empreinte du fichier en clair"
Assert-Equal "S1" $sealSent.Id "envoi en flux : identifiant rendu"
Assert-Equal $sealMd5 (Unprotect-ContentMd5 $sealKeys $sealDoc.appProperties.h) "envoi en flux : empreinte chiffree dans les proprietes"
Assert-Equal $sealKeys.Id $sealDoc.appProperties.k "envoi en flux : identifiant de cle dans les proprietes"
Assert-True ($script:SealMaxBody -le 256KB -and $script:SealMaxBody -gt 0) "envoi en flux : morceaux de 256 Ko au plus"
Assert-True (Test-Deletable $sealPath) "envoi en flux : fichier libere apres l'envoi"
$sealHuge = Join-Path $script:Sandbox "seal-huge.bin"
$sealChunk = New-SealPlain 1MB
$sealFs = [IO.File]::Open($sealHuge, 'Create', 'Write', 'None')
for ($sealIndex = 0; $sealIndex -lt 64; $sealIndex++) { $sealFs.Write($sealChunk, 0, $sealChunk.Length) }
$sealFs.Dispose()
$script:DriveChunkSize = 1MB
$script:SealKeep = $false
$script:SealBytesIn = 0
$script:SealMaxBody = 0
$sealBase = Get-SealLiveBytes
$script:SealMaxMem = $sealBase
$null = Send-SealedPath @{ FolderId = "folder1"; Rel = ".claude/huge.bin"; Path = $sealHuge; Props = @{}; Id = ""; Keys = $sealKeys }
$null = Test-Deletable $sealHuge
Assert-Equal (5 + 16 + 16 * (4194304 + 1) + 32) $script:SealBytesIn "envoi en flux : 64 Mo, octets recus"
Assert-True (($script:SealMaxMem - $sealBase) -lt 24MB) "envoi en flux : memoire stable sur 64 Mo"
$script:DriveChunkSize = $script:SealSavedChunk
. (Join-Path $bin "claude-drive-api.ps1"); if ($script:SealToken) { Set-Item Function:\Get-DriveToken $script:SealToken } else { Remove-Item Function:\Get-DriveToken }
Remove-Item Function:\New-SealPlain, Function:\Read-SealAll, Function:\Get-SealRoundTrip, Function:\Test-SameBytes, Function:\Test-Deletable, Function:\Get-SealLiveBytes
Remove-Variable SealToken, SealSavedChunk, SealKeep, SealUp, SealMeta, SealStartLen, SealMaxBody, SealBytesIn, SealMaxMem -Scope Script -ErrorAction SilentlyContinue
Remove-Variable -Name sealKeys, sealBig, sealBigLen, sealRt, sealShrink, sealSrc, sealBuf, sealFs, sealPath, sealPlain, sealSent, sealDoc, sealMd5, sealHuge, sealChunk, sealBase, sealIndex -ErrorAction SilentlyContinue
