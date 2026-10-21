. (Join-Path $PSScriptRoot "claude-drive-remote-cache.ps1")
$script:DriveChangesUri = "https://www.googleapis.com/drive/v3/changes"
$script:DriveChangeFields = "nextPageToken,newStartPageToken,changes(fileId,removed,file(id,name,md5Checksum,appProperties,parents,trashed))"

function Get-DriveStartToken {
  $r = ConvertFrom-DriveJson (Invoke-DriveRequest "GET" ($script:DriveChangesUri + "/startPageToken?fields=startPageToken"))
  $t = [string]$r.startPageToken
  if (-not $t) { throw "jeton des changements du Drive absent" }
  return $t
}

function Read-DriveChanges {
  param([string]$Token)
  $all = New-Object 'System.Collections.Generic.List[object]'
  $fields = [Uri]::EscapeDataString($script:DriveChangeFields)
  $next = $Token
  while ($true) {
    $uri = $script:DriveChangesUri + "?pageToken=" + [Uri]::EscapeDataString($next) + "&pageSize=1000&includeRemoved=true&spaces=drive&fields=" + $fields
    $r = ConvertFrom-DriveJson (Invoke-DriveRequest "GET" $uri)
    foreach ($c in @($r.changes)) { if ($null -ne $c) { $all.Add($c) } }
    if ($r.nextPageToken) { $next = [string]$r.nextPageToken; continue }
    if (-not $r.newStartPageToken) { throw "fin des changements du Drive sans jeton" }
    return @{ Changes = $all.ToArray(); Token = [string]$r.newStartPageToken }
  }
}

function Remove-CachedId {
  param($Cache, [string]$Id)
  $name = $Cache.Ids[$Id]
  if ($null -eq $name) { return $false }
  $Cache.Ids.Remove($Id)
  $Cache.Files.Remove($name)
  return $true
}

function Test-ChangeGone {
  param($Change, [string]$FolderId)
  $f = $Change.file
  return $Change.removed -eq $true -or $null -eq $f -or $f.trashed -eq $true -or @($f.parents) -cnotcontains $FolderId
}

function Update-RemoteCache {
  param($Cache, $Changes, [string]$Pc)
  $res = @{ Relevant = 0; Anomaly = $false }
  foreach ($c in $Changes) {
    $id = [string]$c.fileId
    if (Test-ChangeGone $c $Cache.Folder) {
      if (Remove-CachedId $Cache $id) { $res.Relevant++ }
      continue
    }
    $e = ConvertTo-RemoteEntry $c.file
    $old = $Cache.Files[$e.Name]
    if ($null -ne $old -and $old.Id -cne $e.Id) { $res.Anomaly = $true; continue }
    $null = Remove-CachedId $Cache $e.Id
    $Cache.Files[$e.Name] = $e
    $Cache.Ids[$e.Id] = $e.Name
    $same = $null -ne $old -and $old.Md5 -eq $e.Md5 -and $old.M -eq $e.M
    if (-not $same -and $e.Pc -ne $Pc) { $res.Relevant++ }
  }
  return $res
}

function Update-RemoteFromChanges {
  param($Folders, [string]$Pc)
  $cache = Read-RemoteCache
  if (-not (Test-RemoteCacheUsable $cache $Folders.Files)) { return $null }
  $r = Read-DriveChanges $cache.Token
  if ($r.Changes.Count -eq 0) { return @{ Files = $cache.Files; Relevant = 0 } }
  $script:RemoteCacheMemo = $null
  $u = Update-RemoteCache $cache $r.Changes $Pc
  if ($u.Anomaly) { return $null }
  $cache.Token = $r.Token
  Save-RemoteCache $cache
  return @{ Files = $cache.Files; Relevant = $u.Relevant }
}

function Get-FullRemoteListing {
  param([string]$FolderId)
  $token = Get-DriveStartToken
  $files = Get-DriveListing $FolderId
  Save-RemoteCache (New-RemoteCache $FolderId $token ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) $files)
  return $files
}

function Get-DriveFilesListing {
  param($Folders, [string]$Pc)
  try { $u = Update-RemoteFromChanges $Folders $Pc } catch { $u = $null }
  if ($null -ne $u) { return $u.Files }
  return Get-FullRemoteListing $Folders.Files
}

function Test-DriveFilesChanged {
  param($Folders, [string]$Pc)
  $u = Update-RemoteFromChanges $Folders $Pc
  return $null -eq $u -or $u.Relevant -gt 0
}
