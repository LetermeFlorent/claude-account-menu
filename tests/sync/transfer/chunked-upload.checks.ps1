. (Join-Path $PSScriptRoot "chunk-fakes.ps1")
try {
  Start-ChkCase 600000 @((New-ChunkMore 262143), (New-ChunkMore 524287), (New-ChunkDone))
  $chunkPuts = @(Get-ChkPuts)
  Assert-Equal "bytes 0-262143/600000,bytes 262144-524287/600000,bytes 524288-599999/600000" (($chunkPuts | ForEach-Object { $_.Range }) -join ",") "envoi par morceaux : trois morceaux en-tetes Content-Range"
  Assert-Equal "262144,262144,75712" (($chunkPuts | ForEach-Object { $_.Length }) -join ",") "envoi par morceaux : tailles des corps"
  Assert-Equal (Get-ChkHash $script:ChunkSource.Bytes) (Get-ChkJoinedHash) "envoi par morceaux : corps recolles egaux a la source"
  Assert-Equal "F1" $script:ChunkResult.Id "envoi par morceaux : identifiant rendu"
  Assert-Equal "m1" $script:ChunkResult.Md5 "envoi par morceaux : empreinte rendue"
  $chunkStart = $script:ChunkCalls[0]
  Assert-Equal "POST" $chunkStart.Method "envoi par morceaux : session ouverte en POST"
  Assert-Equal "https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable&fields=id,md5Checksum" $chunkStart.Uri "envoi par morceaux : adresse de la session"
  Assert-Equal "600000" ([string]$chunkStart.Headers["X-Upload-Content-Length"]) "envoi par morceaux : taille totale annoncee"
  Assert-Equal "https://upload.example/s1" $chunkPuts[0].Uri "envoi par morceaux : morceaux envoyes a l'adresse de session"
  Start-ChkCase 600000 @((New-ChunkMore 99999), (New-ChunkMore 362143), (New-ChunkDone))
  $chunkPuts = @(Get-ChkPuts)
  Assert-Equal "bytes 100000-362143/600000" $chunkPuts[1].Range "308 partiel : reprise au milieu du morceau"
  Assert-Equal (Get-ChkSliceHash 100000 362143) (Get-ChkHash $chunkPuts[1].Body) "308 partiel : corps repris egal a la source"
  Assert-Equal "bytes 362144-599999/600000" $chunkPuts[2].Range "308 partiel : dernier morceau jusqu'a la fin"
  Assert-Equal (Get-ChkHash $script:ChunkSource.Bytes) (Get-ChkJoinedHash) "308 partiel : recollage par decalage egal a la source"
  Start-ChkCase 524288 @((New-ChunkMore 262143), (New-ChunkDone))
  Assert-Equal "bytes 0-262143/524288,bytes 262144-524287/524288" ((Get-ChkPuts | ForEach-Object { $_.Range }) -join ",") "envoi par morceaux : multiple exact, deux morceaux et pas de troisieme"
  Start-ChkCase 0 @(New-ChunkDone)
  $chunkPuts = @(Get-ChkPuts)
  Assert-Equal 1 $chunkPuts.Count "envoi par morceaux : source vide, un seul PUT"
  Assert-Equal "bytes */0" $chunkPuts[0].Range "envoi par morceaux : source vide, Content-Range */0"
  Assert-Equal 0 $chunkPuts[0].Length "envoi par morceaux : source vide, corps vide"
  Start-ChkCase 1000 @(New-ChunkDone) "ID9"
  Assert-Equal "PATCH" $script:ChunkCalls[0].Method "envoi par morceaux : fichier existant en PATCH"
  Assert-True $script:ChunkCalls[0].Uri.StartsWith("https://www.googleapis.com/upload/drive/v3/files/ID9?uploadType=resumable") "envoi par morceaux : fichier existant, adresse avec identifiant"
  Assert-True ($script:ChunkMaxBody -le $script:DriveChunkSize) ("envoi par morceaux : aucun corps au dela de la taille de morceau, " + $script:ChunkMaxBody)
} finally { . $script:ChunkClose }
