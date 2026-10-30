. Import-ClmModule claude-file-io, claude-self-version
$script:ClmMarkerFile = "clm.installing"
$script:ClmManifestFile = "clm.files"
$script:ClmOwnedTops = @("lang", "clm-web")

function Get-ClmTreeFiles {
  param([string]$Root)
  $full = [IO.Path]::GetFullPath($Root).TrimEnd([char[]]@("\", "/"))
  if (-not [IO.Directory]::Exists($full)) { return @() }
  $list = [string[]]@(foreach ($f in [IO.Directory]::GetFiles($full, "*", [IO.SearchOption]::AllDirectories)) { $f.Substring($full.Length + 1).Replace("\", "/") })
  [Array]::Sort($list, [StringComparer]::Ordinal)
  return $list
}

function Test-ClmSameFile {
  param([string]$From, [string]$To)
  if (-not [IO.File]::Exists($To)) { return $false }
  if ((New-Object IO.FileInfo $From).Length -ne (New-Object IO.FileInfo $To).Length) { return $false }
  return [Convert]::ToBase64String([IO.File]::ReadAllBytes($From)) -ceq [Convert]::ToBase64String([IO.File]::ReadAllBytes($To))
}

function Remove-ClmFile {
  param([string]$Path)
  $deadline = [DateTime]::UtcNow.AddMilliseconds($script:SharedWaitMs)
  while ([IO.File]::Exists($Path)) {
    try { [IO.File]::Delete($Path) } catch { if (-not (Test-SharedBusy $_ $deadline)) { throw } }
  }
}

function Copy-ClmFile {
  param([string]$From, [string]$To)
  if (Test-ClmSameFile $From $To) { return }
  $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($To))
  $tmp = $To + "." + [guid]::NewGuid().ToString("N") + ".tmp"
  try {
    [IO.File]::Copy($From, $tmp)
    Move-FileOver $tmp $To
  } finally {
    Remove-ClmFile $tmp
  }
}

function Read-ClmManifest {
  param([string]$Target)
  $p = [IO.Path]::Combine($Target, $script:ClmManifestFile)
  if (-not [IO.File]::Exists($p)) { return @() }
  return @([IO.File]::ReadAllLines($p) | Where-Object { $_ -and -not [IO.Path]::IsPathRooted($_) -and $_.Split([char[]]@("/", "\")) -notcontains ".." })
}

function Get-ClmStaleFiles {
  param([string]$Target, [string[]]$Shipped)
  $keep = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  foreach ($s in $Shipped) { [void]$keep.Add($s) }
  $tops = @($Shipped | Where-Object { $_.Contains("/") } | ForEach-Object { $_.Split("/")[0] } | Select-Object -Unique | Where-Object { $script:ClmOwnedTops -contains $_ })
  $seen = @(foreach ($t in $tops) { Get-ClmTreeFiles ([IO.Path]::Combine($Target, $t)) | ForEach-Object { $t + "/" + $_ } })
  $moved = @($Shipped | Where-Object { $_ -match '/claude-[a-z0-9-]+\.ps1$' } | ForEach-Object { $_.Substring($_.LastIndexOf("/") + 1) } | Where-Object { [IO.File]::Exists([IO.Path]::Combine($Target, $_)) })
  return @(@($seen) + @(Read-ClmManifest $Target) + $moved | Select-Object -Unique | Where-Object { -not $keep.Contains($_) })
}

function Remove-ClmEmptyDirs {
  param([string]$Target, [string]$Rel)
  $parts = $Rel.Split("/")
  for ($n = $parts.Length - 1; $n -ge 1; $n--) {
    $dir = [IO.Path]::Combine($Target, ($parts[0..($n - 1)] -join [IO.Path]::DirectorySeparatorChar))
    if (-not [IO.Directory]::Exists($dir) -or [IO.Directory]::GetFileSystemEntries($dir).Length -gt 0) { return }
    [IO.Directory]::Delete($dir)
  }
}

function Remove-ClmStaleFiles {
  param([string]$Target, [string[]]$Shipped)
  foreach ($rel in Get-ClmStaleFiles $Target $Shipped) {
    $p = [IO.Path]::Combine($Target, $rel)
    Remove-ClmFile $p
    Remove-ClmEmptyDirs $Target $rel
  }
}

function Write-ClmStampFile {
  param([string]$Target, [string]$Version)
  $p = [IO.Path]::Combine($Target, $script:ClmVersionFile)
  if ($Version) { Write-TextFileAtomic $p ($Version.Trim() + "`n") }
  else { Remove-ClmFile $p }
}

function Copy-ClmTree {
  param([string]$Source, [string]$Target, [string[]]$Files)
  $fresh = @($Files | Where-Object { -not [IO.File]::Exists([IO.Path]::Combine($Target, $_)) })
  foreach ($rel in @($fresh) + @($Files | Where-Object { $fresh -cnotcontains $_ })) {
    [IO.File]::SetLastWriteTimeUtc([IO.Path]::Combine($Target, $script:ClmMarkerFile), [DateTime]::UtcNow)
    Copy-ClmFile ([IO.Path]::Combine($Source, $rel)) ([IO.Path]::Combine($Target, $rel))
  }
}

function Install-ClmFiles {
  param([string]$Source, [string]$Target, [string]$Version, [string[]]$Skip = @())
  $null = [IO.Directory]::CreateDirectory($Target)
  $marker = [IO.Path]::Combine($Target, $script:ClmMarkerFile)
  [IO.File]::WriteAllText($marker, [string]$PID)
  try {
    $files = @(Get-ClmTreeFiles $Source | Where-Object { $Skip -cnotcontains $_ })
    Copy-ClmTree $Source $Target $files
    Remove-ClmStaleFiles $Target $files
    Write-TextFileAtomic ([IO.Path]::Combine($Target, $script:ClmManifestFile)) ((@($files) -join "`n") + "`n")
    Write-ClmStampFile $Target $Version
  } finally {
    Remove-ClmFile $marker
  }
}
