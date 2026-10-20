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
$script:DriveSimpleMax = 3
$script:Calls.Clear()
$r = Send-DriveContent "F1" ".claude/big.txt" $f @{ m = "100"; pc = "PC" } ""
$script:DriveSimpleMax = $saved
Assert-Equal 2 $script:Calls.Count "gros fichier : session puis contenu"
Assert-True ($script:Calls[0].Uri.Contains("uploadType=resumable")) "gros fichier : envoi resumable"
Assert-Equal "7" $script:Calls[0].Headers["X-Upload-Content-Length"] "gros fichier : taille annoncee"
Assert-Equal "PUT" $script:Calls[1].Method "gros fichier : contenu en PUT"
Assert-Equal "https://upload.example/session1" $script:Calls[1].Uri "gros fichier : vers la session"
Assert-Equal "bonjour" ([Text.Encoding]::UTF8.GetString($script:Calls[1].Body)) "gros fichier : contenu complet"
Assert-Equal "new1" $r.Id "gros fichier : id rendu"
Assert-True ($script:Calls[0].Body -is [byte[]] -and $script:Calls[1].Body -is [byte[]]) "gros fichier : corps en octets"

$script:Calls.Clear()
Set-DriveProps "P1" @{ ".claude" = "55" }
Assert-True ($script:Calls[0].Uri.EndsWith("/files/P1") -and [Text.Encoding]::UTF8.GetString($script:Calls[0].Body).Contains('".claude": "55"')) "proprietes modifiees"
function Invoke-DriveRequest {
  param([string]$Method, [string]$Uri, $Body = $null, [string]$ContentType = "", [int]$Timeout = 15, [string]$OutFile = "", $Headers = $null)
  if ($Method -eq "GET") { return New-FakeResponse '{"files":[{"id":"k1","name":"c.json","appProperties":{"exp":"100"}},{"id":"k2","name":"c.json","appProperties":{"exp":"200"}}]}' }
  return New-FakeResponse "{}"
}
Assert-Equal "k2" (Get-DriveListing "creds")["c.json"].Id "jetons en double : expiration la plus lointaine gardee"
function Invoke-DriveRequest {
  param([string]$Method, [string]$Uri, $Body = $null, [string]$ContentType = "", [int]$Timeout = 15, [string]$OutFile = "", $Headers = $null)
  $script:MediaOut = $OutFile
  if ([WildcardPattern]::ContainsWildcardCharacters($OutFile)) { throw "chemin pris pour un motif" }
  [IO.File]::WriteAllText($OutFile, "media")
}
$media = Join-Path $script:Sandbox "notes [v2].md"
Save-DriveMedia "m1" $media
Assert-Equal "media" ([IO.File]::ReadAllText($media)) "telechargement vers un nom avec crochets"
Assert-True (-not (Test-Path -LiteralPath $script:MediaOut)) "telechargement : fichier intermediaire retire"
. (Join-Path $bin "claude-drive-transfer.ps1")
Assert-True ($script:Calls[0].Body -is [byte[]]) "metadonnees envoyees en octets, pas en liste de nombres"
