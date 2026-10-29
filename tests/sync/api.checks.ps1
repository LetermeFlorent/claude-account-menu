function New-FakeResponse {
  param([string]$Json, $Headers = @{})
  return [PSCustomObject]@{ RawContentStream = (New-Object IO.MemoryStream(, [Text.Encoding]::UTF8.GetBytes($Json))); Headers = $Headers }
}

$bytes = [byte[]](0, 255, 13, 10, 65)
$body = New-MultipartBody '{"name":"a"}' $bytes "BND"
$text = [Text.Encoding]::GetEncoding(28591).GetString($body)
Assert-True ($text.StartsWith("--BND`r`nContent-Type: application/json; charset=UTF-8`r`n`r`n{""name"":""a""}`r`n--BND`r`nContent-Type: application/octet-stream`r`n`r`n")) "multipart : metadonnees puis contenu"
Assert-True ($text.EndsWith("`r`n--BND--")) "multipart : fin de corps"
$at = $text.IndexOf("octet-stream`r`n`r`n") + 16
Assert-Equal "0,255,13,10,65" (@($body[$at..($at + 4)]) -join ",") "octets binaires intacts"

$script:Calls = New-Object 'System.Collections.Generic.List[object]'
function Invoke-DriveRequest {
  param([string]$Method, [string]$Uri, $Body = $null, [string]$ContentType = "", [int]$Timeout = 15, [string]$OutFile = "", $Headers = $null)
  $script:Calls.Add(@{ Method = $Method; Uri = $Uri; Body = $Body; ContentType = $ContentType; Headers = $Headers })
  if ($Uri -match "pageToken=p2") { return New-FakeResponse '{"files":[{"id":"i3","name":".claude/projets été/a b.md","md5Checksum":"m3","appProperties":{"m":"7","pc":"MAC"}}]}' }
  if ($Method -eq "GET") { return New-FakeResponse '{"nextPageToken":"p2","files":[{"id":"i1","name":"x","md5Checksum":"m1","appProperties":{"m":"5","pc":"A"}},{"id":"i2","name":"x","md5Checksum":"m2","appProperties":{"m":"9","pc":"B","exp":"123"}},{"id":"i4","name":"X","md5Checksum":"m4"}]}' }
  if ($Uri -match "uploadType=resumable") { return New-FakeResponse "" @{ Location = "https://upload.example/session1" } }
  return New-FakeResponse '{"id":"new1","md5Checksum":"abc"}'
}
$l = Get-DriveListing "fold'er"
Assert-Equal 3 $l.Count "listing sur deux pages, doublon fusionne, casse distinguee"
Assert-Equal "i2" $l["x"].Id "doublon : le plus recent garde"
Assert-Equal 9 $l["x"].M "date lue dans appProperties"
Assert-Equal "B" $l["x"].Pc "PC lu dans appProperties"
Assert-Equal 123 $l["x"].Exp "expiration lue"
Assert-Equal "m4" $l["X"].Md5 "nom en majuscules distinct"
Assert-Equal 0 $l["X"].M "sans appProperties, date 0"
Assert-Equal "MAC" $l[".claude/projets été/a b.md"].Pc "nom avec accents, espaces et / rendu tel quel"
Assert-True ($script:Calls[0].Uri.Contains([Uri]::EscapeDataString("'fold\'er' in parents and trashed=false"))) "apostrophe echappee dans la requete"
$trash = @($script:Calls | Where-Object { $_.Method -eq "PATCH" })
Assert-Equal 1 $trash.Count "un doublon mis a la corbeille"
Assert-True ($trash[0].Uri.EndsWith("/files/i1") -and [Text.Encoding]::UTF8.GetString($trash[0].Body).Contains('"trashed": true')) "le doublon le plus ancien part a la corbeille"

$f = [Text.Encoding]::UTF8.GetBytes("bonjour")
$script:Calls.Clear()
$r = Send-DriveContent "F1" ".claude/small.txt" $f @{ m = "100"; pc = "PC" } ""
Assert-Equal "new1" $r.Id "envoi : id rendu"
Assert-Equal "abc" $r.Md5 "envoi : md5 rendu"
Assert-Equal "POST" $script:Calls[0].Method "nouveau fichier : POST"
Assert-True ($script:Calls[0].Body -is [byte[]]) "nouveau fichier : corps en octets"
Assert-True ($script:Calls[0].Uri.StartsWith("https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart")) "nouveau fichier : multipart"
$sent = [Text.Encoding]::UTF8.GetString($script:Calls[0].Body)
Assert-True ($sent.Contains('"parents"') -and $sent.Contains('"F1"') -and $sent.Contains('".claude/small.txt"') -and $sent.Contains('"m": "100"') -and $sent.Contains("bonjour")) "nouveau fichier : nom, dossier, proprietes et contenu"
$script:Calls.Clear()
$null = Send-DriveContent "F1" ".claude/small.txt" $f @{ m = "101"; pc = "PC" } "ID9"
Assert-Equal "PATCH" $script:Calls[0].Method "fichier existant : PATCH"
Assert-True ($script:Calls[0].Uri.StartsWith("https://www.googleapis.com/upload/drive/v3/files/ID9?uploadType=multipart")) "fichier existant : par id"
Assert-True (-not [Text.Encoding]::UTF8.GetString($script:Calls[0].Body).Contains('"parents"')) "fichier existant : dossier inchange"
$saved = $script:DriveSimpleMax
$realChunks = ${function:Send-DriveChunks}
function Send-DriveChunks {
  param([string]$MetaJson, $Source, [string]$Id)
  $buffer = New-Object byte[] ([int]$Source.Length + 4)
  $n = & $Source.Read $Source $buffer 0 $buffer.Length
  $script:Calls.Add(@{ Meta = $MetaJson; Length = $Source.Length; Text = [Text.Encoding]::UTF8.GetString($buffer, 0, $n); Id = $Id })
  return @{ Id = "new1"; Md5 = "abc" }
}
$script:DriveSimpleMax = 3
$script:Calls.Clear()
try { $r = Send-DriveContent "F1" ".claude/big.txt" $f @{ m = "100"; pc = "PC" } "" }
finally { $script:DriveSimpleMax = $saved; Set-Item Function:\Send-DriveChunks $realChunks }
Assert-Equal 1 $script:Calls.Count "gros fichier : envoi par morceaux"
Assert-Equal 7 $script:Calls[0].Length "gros fichier : taille annoncee"
Assert-Equal "bonjour" $script:Calls[0].Text "gros fichier : contenu complet"
Assert-True ($script:Calls[0].Meta.Contains('".claude/big.txt"') -and $script:Calls[0].Meta.Contains('"F1"')) "gros fichier : nom et dossier"
Assert-Equal "new1" $r.Id "gros fichier : id rendu"

$script:Calls.Clear()
Set-DriveProps "P1" @{ ".claude" = "55" }
Assert-True ($script:Calls[0].Uri.EndsWith("/files/P1") -and [Text.Encoding]::UTF8.GetString($script:Calls[0].Body).Contains('".claude": "55"')) "proprietes modifiees"
function Invoke-DriveRequest {
  param([string]$Method, [string]$Uri, $Body = $null, [string]$ContentType = "", [int]$Timeout = 15, [string]$OutFile = "", $Headers = $null)
  if ($Method -eq "GET") { return New-FakeResponse '{"files":[{"id":"k1","name":"c.json","appProperties":{"exp":"100"}},{"id":"k2","name":"c.json","appProperties":{"exp":"200"}}]}' }
  return New-FakeResponse "{}"
}
Assert-Equal "k2" (Get-DriveListing "creds")["c.json"].Id "jetons en double : expiration la plus lointaine gardee"
$apiKeys = New-SyncKeys ([byte[]](50..81)) ([byte[]](1..16)) 600000
$script:MediaBody = Protect-SyncBytes $apiKeys "files/.claude/notes [v2].md" ([Text.Encoding]::UTF8.GetBytes("media"))
function Invoke-DriveRequest {
  param([string]$Method, [string]$Uri, $Body = $null, [string]$ContentType = "", [int]$Timeout = 15, [string]$OutFile = "", $Headers = $null)
  if ($OutFile) { throw "telechargement direct vers un fichier" }
  return [PSCustomObject]@{ RawContentStream = (New-Object IO.MemoryStream(, $script:MediaBody)) }
}
$media = Join-Path $script:Sandbox "notes [v2].md"
Save-SealedMedia "m1" $media "files/.claude/notes [v2].md" $apiKeys
Assert-Equal "media" ([IO.File]::ReadAllText($media)) "telechargement dechiffre vers un nom avec crochets"
$refusedPath = Join-Path $script:Sandbox "refuse.md"
Assert-Throws { Save-SealedMedia "m1" $refusedPath "files/.claude/autre.md" $apiKeys } $script:SealRefused "telechargement sous un autre nom refuse"
$script:MediaBody = [Text.Encoding]::UTF8.GetBytes("en clair")
Assert-Throws { Save-SealedMedia "m1" $refusedPath "files/.claude/notes [v2].md" $apiKeys } $script:SealRefused "telechargement en clair refuse"
Assert-True (-not [IO.File]::Exists($refusedPath)) "fichier refuse jamais ecrit"
Assert-Throws { Save-SealedMedia "m1" $refusedPath "files/x" $null } $script:SealRequired "telechargement sans cle refuse"
$entry = ConvertTo-RemoteEntry ([PSCustomObject]@{ id = "s1"; name = "clm-enc/a"; md5Checksum = "ffff"; appProperties = [PSCustomObject]@{ h = "abc"; m = "5" } })
Assert-Equal "abc|5" ($entry.Md5 + "|" + $entry.M) "fichier chiffre : empreinte en clair lue dans ses proprietes"
Assert-Equal "a1,b2" ((Get-RemoteIds @{ Id = "a1"; SealedId = "a1"; PlainId = "b2" }) -join ",") "suppression : fichier chiffre et copie en clair"
Assert-Equal "c3" ((Get-RemoteIds @{ Id = "c3" }) -join ",") "suppression : fichier simple"
. (Join-Path $bin "claude-drive-transfer.ps1")
Assert-True ($script:Calls[0].Body -is [byte[]]) "metadonnees envoyees en octets, pas en liste de nombres"

$script:Calls.Clear()
function Invoke-DriveRequest {
  param([string]$Method, [string]$Uri, $Body = $null, [string]$ContentType = "", [int]$Timeout = 15, [string]$OutFile = "", $Headers = $null)
  $script:Calls.Add(@{ Method = $Method; Uri = $Uri; Body = $Body; ContentType = $ContentType })
  return New-FakeResponse "--b`r`nContent-Type: application/http`r`n`r`nHTTP/1.1 200 OK`r`n`r`n{}`r`n--b`r`nContent-Type: application/http`r`n`r`nHTTP/1.1 404 Not Found`r`n`r`n{}`r`n--b--"
}
$batch = New-TrashBatchBody @("a1", "b2") "BND"
Assert-True ($batch.StartsWith("--BND`r`nContent-Type: application/http`r`n`r`nPATCH /drive/v3/files/a1?fields=id`r`n")) "corbeille en lot : une requete par fichier"
Assert-True ($batch.Contains("{""trashed"":true}") -and $batch.EndsWith("--BND--`r`n")) "corbeille en lot : corps et fin"
$ids = @(foreach ($i in 1..205) { "id" + $i })
Assert-Equal 3 (Remove-DriveFiles $ids $null 0) "corbeille en lot : reponses en echec non comptees"
Assert-Equal "3 POST https://www.googleapis.com/batch/drive/v3" ("" + $script:Calls.Count + " " + $script:Calls[0].Method + " " + $script:Calls[0].Uri) "corbeille en lot : 100 fichiers par requete"
Assert-True ($script:Calls[0].ContentType.StartsWith("multipart/mixed; boundary=")) "corbeille en lot : corps multipart"
$script:Calls.Clear()
Assert-Equal 0 (Remove-DriveFiles $ids @{ Stop = $true } 0) "corbeille en lot : arret demande"
$lst = New-PathMap
$lst[".claude/projects/p/s.jsonl"] = @{ Id = "c1"; Pc = "PCL" }
$lst[".claude/outils/x/node_modules/m.js"] = @{ Id = "n1"; Pc = "PCL" }
$lst[".claude/projects/p/memory/MEMORY.md"] = @{ Id = "k1"; Pc = "PCL" }
$lst[".claude/projects/p/t.jsonl"] = @{ Id = "bad id"; Pc = "PCL" }
$lst[".claude/skills/.trash/a.md"] = @{ Id = "h1"; Pc = "PCL" }
$lst[".claude/skills/outil/SKILL.md"] = @{ Id = "s1"; Pc = "PCL" }
$own = Get-OwnLeftovers $lst "PCL" (Get-SyncPatterns @([PSCustomObject]@{ Dir = ".claude" }))
Assert-Equal "c1,h1,n1" (($own | Sort-Object) -join ",") "copies a retirer : conversations, modules et dossier masque des skills, pas la memoire, un skill ni un id douteux"
Assert-Equal 0 (Get-OwnLeftovers $lst "PCL" @()).Count "copies a retirer : aucune regle, rien retire"
. (Join-Path $bin "claude-drive-transfer.ps1")
