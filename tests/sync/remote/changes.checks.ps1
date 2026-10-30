$changesSavedCache = $script:RemoteCachePath
$script:RemoteCachePath = Join-Path $script:Sandbox "remote-cache-test.json"
$script:ChangeCalls = New-Object 'System.Collections.Generic.List[string]'
$script:ChangePages = @{}
$script:ChangeFail = $false
$folders = @{ Files = "F1" }

function New-ChangeResponse {
  param([string]$Json)
  return [PSCustomObject]@{ RawContentStream = (New-Object IO.MemoryStream(, [Text.Encoding]::UTF8.GetBytes($Json))) }
}

function Invoke-DriveRequest {
  param($Request)
  $uri = $Request.Uri
  $script:ChangeCalls.Add($uri)
  if ($uri.EndsWith("/changes/startPageToken?fields=startPageToken")) { return New-ChangeResponse '{"startPageToken":"t1"}' }
  if ($uri.StartsWith($script:DriveChangesUri + "?")) {
    if ($script:ChangeFail) { throw "jeton refuse" }
    $tok = [Uri]::UnescapeDataString(([regex]::Match($uri, "pageToken=([^&]+)")).Groups[1].Value)
    return New-ChangeResponse $script:ChangePages[$tok]
  }
  return New-ChangeResponse '{"files":[{"id":"a1","name":"a","md5Checksum":"ma","appProperties":{"m":"5","pc":"PCL"}},{"id":"b1","name":".claude/projets \"ete\"/b.md","md5Checksum":"mb","appProperties":{"m":"6","pc":"MAC"}}]}'
}

function Get-ChangeCallCount {
  param([string]$Part)
  return @($script:ChangeCalls | Where-Object { $_.Contains($Part) }).Count
}

$bName = '.claude/projets "ete"/b.md'
$l = Get-DriveFilesListing $folders "PCL"
Assert-Equal 2 $l.Count "liste du Drive : premiere fois complete"
Assert-True ($script:ChangeCalls[0].Contains("startPageToken") -and $script:ChangeCalls[1].Contains("?q=")) "liste du Drive : jeton pris avant la liste"
$c = Read-RemoteCache
Assert-Equal "F1|t1|mb|MAC" ($c.Folder + "|" + $c.Token + "|" + $c.Files[$bName].Md5 + "|" + $c.Files[$bName].Pc) "liste du Drive : cache relu a l'identique"
Assert-Equal "a" $c.Ids["a1"] "liste du Drive : index des ids"

$script:ChangePages["t1"] = '{"nextPageToken":"t1b","changes":[{"fileId":"c1","removed":false,"file":{"id":"c1","name":"c","md5Checksum":"mc","parents":["F1"],"appProperties":{"m":"8","pc":"MAC"}}},{"fileId":"a1","removed":false,"file":{"id":"a1","name":"a","trashed":true,"parents":["F1"]}}]}'
$script:ChangePages["t1b"] = '{"newStartPageToken":"t2","changes":[{"fileId":"b1","removed":false,"file":{"id":"b1","name":".claude/projets \"ete\"/b.md","md5Checksum":"mb2","parents":["F1"],"appProperties":{"m":"9","pc":"PCL"}}},{"fileId":"k1","removed":false,"file":{"id":"k1","name":"cred.json","parents":["C1"]}},{"fileId":"zz","removed":true}]}'
$script:ChangeCalls.Clear()
$l = Get-DriveFilesListing $folders "PCL"
Assert-True ($l.Count -eq 2 -and $l.ContainsKey("c") -and $l.ContainsKey($bName)) "changements : ajout, corbeille, autre dossier ignore"
Assert-Equal "mb2" $l[$bName].Md5 "changements : fichier modifie"
Assert-Equal 0 (Get-ChangeCallCount "?q=") "changements : pas de liste complete"
Assert-Equal "t2" (Read-RemoteCache).Token "changements : nouveau jeton garde"

function Set-NextChanges {
  param([string]$Changes, [string]$Next)
  $script:ChangePages[(Read-RemoteCache).Token] = '{"newStartPageToken":"' + $Next + '","changes":[' + $Changes + ']}'
}

Set-NextChanges "" "t3"
$stamp = Get-RemoteCacheStamp
Assert-True (-not (Test-DriveFilesChanged $folders "PCL")) "veille : rien de neuf"
Assert-Equal "t2" (Read-RemoteCache).Token "veille : rien de neuf, cache pas reecrit"
Assert-Equal $stamp (Get-RemoteCacheStamp) "veille : rien de neuf, fichier intact"
Set-NextChanges '{"fileId":"d1","file":{"id":"d1","name":"d","md5Checksum":"md","parents":["F1"],"appProperties":{"m":"3","pc":"PCL"}}}' "t4"
Assert-True (-not (Test-DriveFilesChanged $folders "PCL")) "veille : envoi de ce PC seulement"
Set-NextChanges '{"fileId":"c1","file":{"id":"c1","name":"c","md5Checksum":"mc","parents":["F1"],"appProperties":{"m":"8","pc":"MAC"}}}' "t5"
Assert-True (-not (Test-DriveFilesChanged $folders "PCL")) "veille : fichier inchange"
Set-NextChanges '{"fileId":"d1","removed":true}' "t6"
Assert-True (Test-DriveFilesChanged $folders "PCL") "veille : fichier retire ailleurs"
Set-NextChanges '{"fileId":"e1","file":{"id":"e1","name":"e","md5Checksum":"me","parents":["F1"],"appProperties":{"m":"4","pc":"MAC"}}}' "t7"
Assert-True (Test-DriveFilesChanged $folders "PCL") "veille : envoi d'un autre PC"
$script:RemoteCacheMemo = $null
$c = Read-RemoteCache
Assert-Equal "t7|me|MAC|4|3" ($c.Token + "|" + $c.Files["e"].Md5 + "|" + $c.Files["e"].Pc + "|" + $c.Files["e"].M + "|" + $c.Files.Count) "veille : cache relu depuis le disque"

Set-NextChanges '{"fileId":"x9","file":{"id":"x9","name":"c","md5Checksum":"mx","parents":["F1"]}}' "t8"
$script:ChangeCalls.Clear()
$l = Get-DriveFilesListing $folders "PCL"
Assert-Equal 1 (Get-ChangeCallCount "?q=") "doublon : liste complete"
Assert-Equal "t1" (Read-RemoteCache).Token "doublon : cache refait"

$script:ChangeFail = $true
$script:ChangeCalls.Clear()
$null = Get-DriveFilesListing $folders "PCL"
Assert-Equal 1 (Get-ChangeCallCount "?q=") "jeton refuse : liste complete"
$script:ChangeFail = $false

$c = Read-RemoteCache
$c.Full = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $script:RemoteFullSeconds - 1
Save-RemoteCache $c
Assert-True (-not (Test-RemoteCacheUsable (Read-RemoteCache) "F1")) "cache d'un jour : liste complete"
Assert-True (-not (Test-RemoteCacheUsable $c "F2")) "autre dossier : liste complete"
[IO.File]::WriteAllText($script:RemoteCachePath, "{pas du json")
Assert-Null (Read-RemoteCache) "cache illisible ignore"
Assert-True (Test-DriveFilesChanged $folders "PCL") "veille sans cache : synchro"

Remove-Item -LiteralPath $script:RemoteCachePath -Force -ErrorAction SilentlyContinue
$script:RemoteCachePath = $changesSavedCache
. (Join-Path $bin "claude-drive-changes.ps1")
