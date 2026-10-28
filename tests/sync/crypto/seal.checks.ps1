$sealKeys = New-SyncKeys ([byte[]](1..32)) ([byte[]](1..16)) 1000
$otherKeys = New-SyncKeys ([byte[]](2..33)) ([byte[]](1..16)) 1000
$sealPath = "files/.claude/settings.json"
$sealPlain = [Text.Encoding]::UTF8.GetBytes('{"hooks":{"SessionStart":[]}}')
$box = Protect-SyncBytes $sealKeys $sealPath $sealPlain
Assert-Equal '{"hooks":{"SessionStart":[]}}' ([Text.Encoding]::UTF8.GetString((Unprotect-SyncBytes $sealKeys $sealPath $box))) "chiffrement : aller-retour"
Assert-True (-not [Text.Encoding]::UTF8.GetString($box).Contains("hooks")) "chiffrement : contenu illisible sur le Drive"
$boxAgain = Protect-SyncBytes $sealKeys $sealPath $sealPlain
Assert-True ([Convert]::ToBase64String($boxAgain) -ne [Convert]::ToBase64String($box)) "chiffrement : vecteur neuf a chaque envoi"
Assert-Equal 0 (Unprotect-SyncBytes $sealKeys $sealPath (Protect-SyncBytes $sealKeys $sealPath ([byte[]]@()))).Length "chiffrement : fichier vide"
foreach ($at in @(0, 4, 8, ($box.Length - 40), ($box.Length - 1))) {
  $bad = [byte[]]$box.Clone()
  $bad[$at] = $bad[$at] -bxor 1
  Assert-Throws { Unprotect-SyncBytes $sealKeys $sealPath $bad } $script:SealRefused ("chiffrement : octet " + $at + " modifie refuse")
}
Assert-Throws { Unprotect-SyncBytes $sealKeys "files/.claude/CLAUDE.md" $box } $script:SealRefused "chiffrement : fichier renomme refuse"
Assert-Throws { Unprotect-SyncBytes $sealKeys $sealPath $sealPlain } $script:SealRefused "chiffrement : fichier en clair refuse"
Assert-Throws { Unprotect-SyncBytes $otherKeys $sealPath $box } $script:SealRefused "chiffrement : autre phrase refusee"
Assert-Throws { Unprotect-SyncBytes $sealKeys $sealPath ([byte[]]$box[0..40]) } $script:SealRefused "chiffrement : fichier tronque refuse"
$sealErr = $null
try { $null = Unprotect-SyncBytes $sealKeys $sealPath $sealPlain } catch { $sealErr = $_ }
Assert-True (Test-SealRefusal $sealErr) "chiffrement : refus reconnu"
$otherErr = $null
try { throw "panne reseau" } catch { $otherErr = $_ }
Assert-True (-not (Test-SealRefusal $otherErr)) "chiffrement : panne ordinaire distincte d'un refus"

$md5 = "0123456789abcdef0123456789abcdef"
$tag = Protect-ContentMd5 $sealKeys $md5
Assert-True ($tag.StartsWith($sealKeys.Id) -and -not $tag.Contains($md5)) "empreinte : marquee par la cle, sans le md5 en clair"
Assert-Equal $md5 (Unprotect-ContentMd5 $sealKeys $tag) "empreinte : relue avec la meme cle"
Assert-Equal "" (Unprotect-ContentMd5 $otherKeys $tag) "empreinte : autre cle ignoree"
Assert-Equal "" (Unprotect-ContentMd5 $sealKeys "abc") "empreinte : valeur abimee ignoree"
Assert-Equal $tag (Protect-ContentMd5 $sealKeys $md5) "empreinte : stable pour un meme contenu"
Assert-True ($sealKeys.Enc.Length -eq 32 -and $sealKeys.Mac.Length -eq 32 -and [Convert]::ToBase64String($sealKeys.Enc) -ne [Convert]::ToBase64String($sealKeys.Mac)) "cles : chiffrement et signature distinctes"
