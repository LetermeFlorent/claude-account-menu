. Import-ClmModule claude-drive-api, claude-state, claude-drive-lock
$script:DriveFoldersWaitMs = 15000
$script:DriveFoldersTrustMs = 600000
$script:DriveFolderKeys = @("Root", "Files", "Credentials", "Presence")

function Find-DriveFolder {
  param([string]$Name, [string]$Parent)
  $q = "name='" + (ConvertTo-DriveQuery $Name) + "' and mimeType='" + $script:DriveFolderMime + "' and trashed=false and '" + (ConvertTo-DriveQuery $Parent) + "' in parents"
  $uri = $script:DriveApi + "?q=" + [Uri]::EscapeDataString($q) + "&orderBy=createdTime&pageSize=10&fields=files(id)"
  $r = ConvertFrom-DriveJson (Invoke-DriveRequest @{ Method = "GET"; Uri = $uri })
  if (@($r.files).Count -gt 0) { return [string]@($r.files)[0].id }
  $meta = [ordered]@{ name = $Name; mimeType = $script:DriveFolderMime; parents = @($Parent) }
  $r = ConvertFrom-DriveJson (Invoke-DriveRequest @{ Method = "POST"; Uri = ($script:DriveApi + "?fields=id"); Body = (ConvertTo-JsonBytes $meta); ContentType = $script:DriveJsonType })
  return [string]$r.id
}

function Get-DriveChildFolders {
  param([string]$Parent)
  $q = "'" + (ConvertTo-DriveQuery $Parent) + "' in parents and mimeType='" + $script:DriveFolderMime + "' and trashed=false"
  $uri = $script:DriveApi + "?q=" + [Uri]::EscapeDataString($q) + "&pageSize=100&fields=files(id)"
  $r = ConvertFrom-DriveJson (Invoke-DriveRequest @{ Method = "GET"; Uri = $uri; Timeout = $script:DriveMetaTimeout })
  return @($r.files | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_.id })
}

function Get-CachedDriveFolders {
  $c = Read-DriveConfig
  if ($null -eq $c) { return $null }
  $out = @{}
  foreach ($k in $script:DriveFolderKeys) { $out[$k] = [string]$c[("folder" + $k)] }
  if (@($script:DriveFolderKeys | Where-Object { -not $out[$_] }).Count -gt 0) { return $null }
  $key = Get-DriveFoldersKey $out
  if ((Read-MachineStamp $script:DriveFoldersLock $script:DriveFoldersTrustMs) -eq $key) { return $out }
  try { $alive = Get-DriveChildFolders $out.Root }
  catch { if ($_.Exception.Data["HttpStatus"] -eq 404) { return $null }; throw }
  foreach ($k in @("Files", "Credentials", "Presence")) { if ($alive -notcontains $out[$k]) { return $null } }
  Write-MachineStamp $script:DriveFoldersLock $key
  return $out
}

function Get-DriveFoldersKey {
  param($Folders)
  return @($script:DriveFolderKeys | ForEach-Object { $Folders[$_] }) -join "|"
}

function Reset-DriveFoldersCheck {
  Write-MachineStamp $script:DriveFoldersLock ""
}

function New-DriveFolders {
  $out = @{ Root = (Find-DriveFolder $script:DriveFolderNames.Root "root") }
  foreach ($k in @("Files", "Credentials", "Presence")) { $out[$k] = Find-DriveFolder $script:DriveFolderNames[$k] $out.Root }
  $c = Read-DriveConfig
  if ($null -eq $c) { $c = @{} }
  foreach ($k in $script:DriveFolderKeys) { $c[("folder" + $k)] = $out[$k] }
  Save-DriveConfig $c
  Write-MachineStamp $script:DriveFoldersLock (Get-DriveFoldersKey $out)
  return $out
}

function Clear-DriveFolderIds {
  $c = Read-DriveConfig
  if ($null -ne $c) {
    foreach ($k in $script:DriveFolderKeys) { $c.Remove("folder" + $k) }
    Save-DriveConfig $c
  }
  Reset-DriveFoldersCheck
}

function Invoke-WithFolderRetry {
  param([scriptblock]$Action)
  try { return & $Action }
  catch {
    if ($_.Exception.Data["FolderGone"] -ne $true) { throw }
    Clear-DriveFolderIds
    return & $Action
  }
}

function Get-DriveFolders {
  $out = Get-CachedDriveFolders
  if ($null -ne $out) { return $out }
  return Invoke-WithMachineLock $script:DriveFoldersLock $script:DriveFoldersWaitMs {
    $again = Get-CachedDriveFolders
    if ($null -ne $again) { return $again }
    return New-DriveFolders
  }
}
