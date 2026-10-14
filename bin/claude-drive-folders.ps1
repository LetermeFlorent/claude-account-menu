. (Join-Path $PSScriptRoot "claude-drive-api.ps1")
$script:DriveFoldersLockPath = Join-Path (Get-HomeDir) ".clm-drive-folders.lock"
$script:DriveFoldersWaitMs = 15000
$script:DriveFolderKeys = @("Root", "Files", "Credentials", "Presence")

function Find-DriveFolder {
  param([string]$Name, [string]$Parent)
  $q = "name='" + (ConvertTo-DriveQuery $Name) + "' and mimeType='" + $script:DriveFolderMime + "' and trashed=false and '" + (ConvertTo-DriveQuery $Parent) + "' in parents"
  $uri = $script:DriveApi + "?q=" + [Uri]::EscapeDataString($q) + "&orderBy=createdTime&pageSize=10&fields=files(id)"
  $r = ConvertFrom-DriveJson (Invoke-DriveRequest "GET" $uri)
  if (@($r.files).Count -gt 0) { return [string]@($r.files)[0].id }
  $meta = [ordered]@{ name = $Name; mimeType = $script:DriveFolderMime; parents = @($Parent) }
  $r = ConvertFrom-DriveJson (Invoke-DriveRequest "POST" ($script:DriveApi + "?fields=id") (ConvertTo-JsonBytes $meta) $script:DriveJsonType)
  return [string]$r.id
}

function Get-DriveChildFolders {
  param([string]$Parent)
  $q = "'" + (ConvertTo-DriveQuery $Parent) + "' in parents and mimeType='" + $script:DriveFolderMime + "' and trashed=false"
  $uri = $script:DriveApi + "?q=" + [Uri]::EscapeDataString($q) + "&pageSize=100&fields=files(id)"
  $r = ConvertFrom-DriveJson (Invoke-DriveRequest "GET" $uri $null "" $script:DriveMetaTimeout)
  return @($r.files | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_.id })
}

function Get-CachedDriveFolders {
  $c = Read-DriveConfig
  if ($null -eq $c) { return $null }
  $out = @{}
  foreach ($k in $script:DriveFolderKeys) { $out[$k] = [string]$c[("folder" + $k)] }
  if (@($script:DriveFolderKeys | Where-Object { -not $out[$_] }).Count -gt 0) { return $null }
  $alive = Get-DriveChildFolders $out.Root
  foreach ($k in @("Files", "Credentials", "Presence")) { if ($alive -notcontains $out[$k]) { return $null } }
  return $out
}

function New-DriveFolders {
  $out = @{ Root = (Find-DriveFolder $script:DriveFolderNames.Root "root") }
  foreach ($k in @("Files", "Credentials", "Presence")) { $out[$k] = Find-DriveFolder $script:DriveFolderNames[$k] $out.Root }
  $c = Read-DriveConfig
  if ($null -eq $c) { $c = @{} }
  foreach ($k in $script:DriveFolderKeys) { $c[("folder" + $k)] = $out[$k] }
  Save-DriveConfig $c
  return $out
}

function Get-DriveFolders {
  $out = Get-CachedDriveFolders
  if ($null -ne $out) { return $out }
  return Invoke-WithFileLock $script:DriveFoldersLockPath $script:DriveFoldersWaitMs "dossier Drive en cours de creation" {
    $again = Get-CachedDriveFolders
    if ($null -ne $again) { return $again }
    return New-DriveFolders
  }
}
