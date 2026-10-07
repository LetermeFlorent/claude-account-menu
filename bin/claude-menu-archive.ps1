. (Join-Path $PSScriptRoot "claude-platform.ps1")
. (Join-Path $PSScriptRoot "claude-menu-progress.ps1")
$script:Tar = $null
$script:TarFlavor = $null

function Get-TarFlavor {
  param([string]$VersionText)
  if ($VersionText -match "bsdtar|libarchive") { return "bsd" }
  return "gnu"
}

function Get-ArchiveExtension {
  param([string]$Flavor)
  if ($Flavor -eq "bsd") { return ".zip" }
  return ".tar.gz"
}

function Initialize-Tar {
  if ($script:Tar) { return }
  if ($script:OsName -eq "Windows") {
    $script:Tar = Join-Path $env:SystemRoot "System32\tar.exe"
    $script:TarFlavor = "bsd"
    return
  }
  $script:Tar = "tar"
  foreach ($n in @("bsdtar", "tar")) {
    $c = Get-Command $n -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c) { $script:Tar = $c.Source; break }
  }
  $script:TarFlavor = Get-TarFlavor ((& $script:Tar --version 2>$null) -join " ")
}

function Assert-ArchiveReadable {
  param([string]$Path)
  Initialize-Tar
  if ($script:TarFlavor -eq "gnu" -and $Path -like "*.zip") {
    throw "GNU tar ne lit pas les zip : installer bsdtar (paquet libarchive-tools) pour restaurer ce fichier"
  }
}

function Get-XdgDownloads {
  $h = Get-HomeDir
  $f = [IO.Path]::Combine((Get-XdgDir "XDG_CONFIG_HOME" @(".config")), "user-dirs.dirs")
  if (-not (Test-Path -LiteralPath $f)) { return $null }
  foreach ($l in Get-Content -LiteralPath $f -Encoding UTF8) {
    if ($l -match '^\s*XDG_DOWNLOAD_DIR\s*=\s*"(.+)"\s*$') { return $Matches[1].Replace('$HOME', $h) }
  }
  return $null
}

function Get-WindowsDownloads {
  $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
  try {
    $raw = (Get-Item -LiteralPath $key).GetValue("{374DE290-123F-4565-9164-39C4925E467B}", $null, "DoNotExpandEnvironmentNames")
    if ($raw) { return [Environment]::ExpandEnvironmentVariables($raw) }
  } catch {}
  return $null
}

function Get-DownloadsDir {
  $p = $null
  if ($script:OsName -eq "Windows") { $p = Get-WindowsDownloads }
  elseif ($script:OsName -eq "Linux") { $p = Get-XdgDownloads }
  if ($p -and (Test-Path -LiteralPath $p)) { return $p }
  $p = Join-Path (Get-HomeDir) "Downloads"
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Path $p | Out-Null }
  return $p
}

function Invoke-Tar {
  param([string[]]$Argv, [long]$Total, [string]$Label)
  Initialize-Tar
  $base = Join-Path ([IO.Path]::GetTempPath()) ("claude-tar-" + [guid]::NewGuid().ToString("N"))
  $out = $base + ".out.log"
  $err = $base + ".err.log"
  $quoted = @("-v") + $Argv | ForEach-Object { if ($_ -match "^-") { $_ } else { '"' + $_ + '"' } }
  $p = Start-Process -FilePath $script:Tar -ArgumentList $quoted -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
  try { $p.PriorityClass = "BelowNormal" } catch {}
  Wait-Tar $p $out $err $Total $Label
  $warn = @(Read-TarLog $err | Where-Object { $_ -notmatch "^[ax] " })
  foreach ($f in @($out, $err)) { if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force } }
  return $warn
}
