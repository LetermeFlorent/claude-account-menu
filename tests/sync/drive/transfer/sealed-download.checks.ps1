. Import-ClmModule claude-drive-transfer-open
. (Join-Path $bin "drive/transfer/claude-drive-transfer.ps1")
$script:OpenKeys = New-SyncKeys ([byte[]](50..81)) ([byte[]](1..16)) 600000
. (Join-Path $bin "drive/core/claude-drive-api.ps1"); $script:OpenToken = ${function:Get-DriveToken}
function New-OpenPlain {
  param([int]$Length)
  $bytes = New-Object byte[] $Length
  for ($i = 0; $i -lt $Length; $i += 997) { $bytes[$i] = [byte](($i / 997) % 256) }
  return ,$bytes
}
function New-OpenBox {
  param([byte[]]$Bytes, [string]$Name)
  $path = Join-Path $script:Sandbox $Name
  [IO.File]::WriteAllBytes($path, $Bytes)
  return $path
}
function Test-OpenRefused {
  param([byte[]]$Box, [string]$Seal, [string]$Name)
  $out = Join-Path $script:Sandbox "open-refused.bin"
  $from = New-OpenBox $Box "open-refused.box"
  Assert-Throws { Expand-SealedFile $script:OpenKeys $Seal $from $out } (Get-ClmText "sync.crypto.refused") ("dechiffrement en flux : " + $Name + " refuse")
  Assert-True (-not [IO.File]::Exists($out)) ("dechiffrement en flux : " + $Name + ", rien ecrit")
}
$openSeal = "files/.claude/gros.bin"
$openPlain = New-OpenPlain 200001
$openBox = Protect-SyncBytes $script:OpenKeys $openSeal $openPlain
$openOut = Join-Path $script:Sandbox "open-out.bin"
Expand-SealedFile $script:OpenKeys $openSeal (New-OpenBox $openBox "open-in.box") $openOut
Assert-Equal ([Convert]::ToBase64String($openPlain)) ([Convert]::ToBase64String([IO.File]::ReadAllBytes($openOut))) "dechiffrement en flux : aller-retour"
Expand-SealedFile $script:OpenKeys $openSeal (New-OpenBox (Protect-SyncBytes $script:OpenKeys $openSeal ([byte[]]@())) "open-empty.box") $openOut
Assert-Equal 0 ([IO.FileInfo]$openOut).Length "dechiffrement en flux : fichier vide"
Test-OpenRefused $openBox "files/.claude/autre.bin" "autre nom"
$openBad = [byte[]]$openBox.Clone()
$openBad[100000] = $openBad[100000] -bxor 1
Test-OpenRefused $openBad $openSeal "octet modifie"
Test-OpenRefused ([byte[]]$openBox[0..($openBox.Length - 11)]) $openSeal "fichier tronque"
Test-OpenRefused $openPlain $openSeal "fichier en clair"
Test-OpenRefused (Protect-SyncBytes (New-SyncKeys ([byte[]](1..32)) ([byte[]](1..16)) 600000) $openSeal $openPlain) $openSeal "autre phrase"
$script:OpenRequests = New-Object 'System.Collections.Generic.List[object]'
try {
  function Get-DriveToken { param([switch]$Renew) return "tok" }
  function Invoke-DriveWeb {
    param($Request)
    $script:OpenRequests.Add($Request)
    [IO.File]::WriteAllBytes($Request.OutFile, $script:OpenServed)
  }
  $script:OpenServed = $openBox
  $openMedia = Join-Path $script:Sandbox "open-media.bin"
  Save-SealedMedia "m9" $openMedia $openSeal $script:OpenKeys
  Assert-Equal ([Convert]::ToBase64String($openPlain)) ([Convert]::ToBase64String([IO.File]::ReadAllBytes($openMedia))) "telechargement en flux : contenu dechiffre"
  $openReq = $script:OpenRequests[0]
  Assert-True ($openReq.OutFile -like "*.tmp" -and -not $openReq.ContainsKey("PassThru")) "telechargement en flux : corps ecrit sur disque, pas garde en memoire"
  Assert-True (-not [IO.File]::Exists($openReq.OutFile)) "telechargement en flux : fichier chiffre retire"
  $script:OpenServed = $openBad
  $openRefused = Join-Path $script:Sandbox "open-media-refused.bin"
  Assert-Throws { Save-SealedMedia "m9" $openRefused $openSeal $script:OpenKeys } (Get-ClmText "sync.crypto.refused") "telechargement en flux : fichier modifie refuse"
  Assert-True (-not [IO.File]::Exists($openRefused) -and -not [IO.File]::Exists($script:OpenRequests[1].OutFile)) "telechargement en flux : refuse, aucun fichier laisse"
} finally {
  . (Join-Path $bin "drive/core/claude-drive-api.ps1"); if ($script:OpenToken) { Set-Item Function:\Get-DriveToken $script:OpenToken } else { Remove-Item Function:\Get-DriveToken }
}
Remove-Item Function:\New-OpenPlain, Function:\New-OpenBox, Function:\Test-OpenRefused
Remove-Variable OpenKeys, OpenToken, OpenRequests, OpenServed -Scope Script -ErrorAction SilentlyContinue
Remove-Variable openSeal, openPlain, openBox, openOut, openBad, openMedia, openReq, openRefused -ErrorAction SilentlyContinue
