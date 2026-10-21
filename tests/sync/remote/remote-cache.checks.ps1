$remoteCacheSaved = $script:RemoteCachePath
$script:RemoteCachePath = Join-Path $script:Sandbox "remote-cache-read.json"

function Read-RemoteCacheFromDisk {
  $script:RemoteCacheMemo = $null
  return Read-RemoteCache
}

$rcFiles = New-PathMap
$rcFiles[".claude/a.md"] = New-RemoteEntry "i1" ".claude/a.md" "m1" @{ m = "5"; pc = "PCA"; exp = "0" }
$rcFiles[".claude/b.md"] = New-RemoteEntry "i2" ".claude/b.md" "" @{ m = "-3"; pc = ""; exp = "99" }
Save-RemoteCache (New-RemoteCache "F1" "t1" 42 $rcFiles)
$rcText = [IO.File]::ReadAllText($script:RemoteCachePath)
$rcFast = ConvertFrom-RemoteCacheRows $rcText
Assert-True ($null -ne $rcFast) "cache distant : lecture rapide du format ecrit"
$a = $rcFast.Files[".claude/a.md"]; $b = $rcFast.Files[".claude/b.md"]
Assert-Equal "F1|t1|42|2" ($rcFast.Folder + "|" + $rcFast.Token + "|" + $rcFast.Full + "|" + $rcFast.Files.Count) "cache distant : en-tete relu"
Assert-Equal "i1|.claude/a.md|m1|5|PCA|0" ($a.Id + "|" + $a.Name + "|" + $a.Md5 + "|" + $a.M + "|" + $a.Pc + "|" + $a.Exp) "cache distant : entree relue"
Assert-Equal "-3||99|-3" ([string]$b.M + "|" + $b.Pc + "|" + $b.Exp + "|" + $b.Props.m) "cache distant : negatif et vides relus"
Assert-Equal ".claude/b.md" $rcFast.Ids["i2"] "cache distant : index des ids"
Assert-Equal "5|PCA|0" ($a.Props.m + "|" + $a.Props.pc + "|" + $a.Props.exp) "cache distant : proprietes en texte"

$rcFiles['.claude/q"x\y.md'] = New-RemoteEntry "i3" '.claude/q"x\y.md' "m3" @{ m = "7"; pc = "PCB"; exp = "0" }
Save-RemoteCache (New-RemoteCache "F1" "t2" 43 $rcFiles)
Assert-Null (ConvertFrom-RemoteCacheRows ([IO.File]::ReadAllText($script:RemoteCachePath))) "cache distant : nom echappe, lecteur complet"
$rcFull = Read-RemoteCacheFromDisk
Assert-Equal "t2|3|i3|PCB" ($rcFull.Token + "|" + $rcFull.Files.Count + "|" + $rcFull.Files['.claude/q"x\y.md'].Id + "|" + $rcFull.Files['.claude/q"x\y.md'].Pc) "cache distant : nom echappe relu"

[IO.File]::WriteAllText($script:RemoteCachePath, $rcText.Replace("`n", "`r`n"))
$rcCrlf = Read-RemoteCacheFromDisk
Assert-Equal "t1|2|m1" ($rcCrlf.Token + "|" + $rcCrlf.Files.Count + "|" + $rcCrlf.Files[".claude/a.md"].Md5) "cache distant en CRLF relu"

Save-RemoteCache (New-RemoteCache "F1" "t3" 44 (New-PathMap))
$rcEmpty = ConvertFrom-RemoteCacheRows ([IO.File]::ReadAllText($script:RemoteCachePath))
Assert-Equal "t3|0" ($rcEmpty.Token + "|" + $rcEmpty.Files.Count) "cache distant vide relu"

Remove-Item -LiteralPath $script:RemoteCachePath -Force -ErrorAction SilentlyContinue
$script:RemoteCachePath = $remoteCacheSaved
$script:RemoteCacheMemo = $null
