. (Join-Path $PSScriptRoot "chunk-fakes.ps1")
try {
  Start-ChkCase 600000 @((New-ChunkFailure 503), (New-ChunkMore 131071), (New-ChunkMore 393215), (New-ChunkDone))
  $chunkPuts = @(Get-ChkPuts)
  Assert-Equal "bytes 0-262143/600000,bytes */600000,bytes 131072-393215/600000,bytes 393216-599999/600000" (($chunkPuts | ForEach-Object { $_.Range }) -join ",") "envoi par morceaux : 503 puis etat demande puis reprise a 131072"
  Assert-Equal 1 $script:ChunkSlept.Count "envoi par morceaux : une attente apres le 503"
  Assert-Equal (Get-ChkSliceHash 131072 393215) (Get-ChkHash $chunkPuts[2].Body) "envoi par morceaux : corps repris apres 503 egal a la source"
  foreach ($chunkStatus in 500, 502, 504, 429, 0) {
    Start-ChkCase 300000 @((New-ChunkFailure $chunkStatus), (New-ChunkMore $null), (New-ChunkMore 262143), (New-ChunkDone))
    Assert-Equal "bytes 0-262143/300000,bytes */300000,bytes 0-262143/300000,bytes 262144-299999/300000" ((Get-ChkPuts | ForEach-Object { $_.Range }) -join ",") ("envoi par morceaux : statut " + $chunkStatus + " repris")
  }
  Start-ChkCase 600000 @((New-ChunkFailure 503), (New-ChunkMore $null), (New-ChunkMore 262143), (New-ChunkMore 524287), (New-ChunkDone))
  Assert-Equal "bytes 0-262143/600000,bytes */600000,bytes 0-262143/600000,bytes 262144-524287/600000,bytes 524288-599999/600000" ((Get-ChkPuts | ForEach-Object { $_.Range }) -join ",") "envoi par morceaux : 308 sans Range repart a zero"
  $script:DriveChunkRetryMax = 2
  Start-ChkCase 600000 @(1..30 | ForEach-Object { New-ChunkFailure 503 })
  Assert-True $script:ChunkFailed.StartsWith("!") "envoi par morceaux : echecs repetes finissent en erreur"
  Assert-True (@(Get-ChkPuts).Count -le 6) ("envoi par morceaux : nombre d'appels borne, " + @(Get-ChkPuts).Count)
  Start-ChkCase 600000 @(1..30 | ForEach-Object { New-ChunkMore $null })
  Assert-True $script:ChunkFailed.StartsWith("!Drive : l'envoi n'avance plus") ("envoi par morceaux : 308 sans progres finit en erreur, " + $script:ChunkFailed)
  Assert-Equal 3 @(Get-ChkPuts).Count "envoi par morceaux : 308 sans progres, renvois bornes"
  Assert-Equal 2 $script:ChunkSlept.Count "envoi par morceaux : 308 sans progres, attente avant chaque renvoi"
  $script:DriveChunkRetryMax = $script:ChunkSaved.Max
  Start-ChkCase 100000 @((New-ChunkFailure 401), (New-ChunkDone))
  $chunkPuts = @(Get-ChkPuts)
  Assert-Equal 1 @($script:ChunkRenews | Where-Object { $_ }).Count "envoi par morceaux : 401 renouvelle le jeton une fois"
  Assert-Equal 2 $chunkPuts.Count "envoi par morceaux : 401 renvoie le morceau"
  Assert-Equal $chunkPuts[0].Range $chunkPuts[1].Range "envoi par morceaux : meme Content-Range apres 401"
  Assert-Equal 0 $script:ChunkSlept.Count "envoi par morceaux : 401 sans attente"
  Start-ChkCase 600000 @((New-ChunkFailure 404))
  Assert-True $script:ChunkFailed.StartsWith("!") "envoi par morceaux : 404 session expiree en erreur"
  Assert-Equal 1 @(Get-ChkPuts).Count "envoi par morceaux : 404 sans reprise"
  Assert-Equal 0 $script:ChunkSlept.Count "envoi par morceaux : 404 sans attente"
} finally { . $script:ChunkClose }
