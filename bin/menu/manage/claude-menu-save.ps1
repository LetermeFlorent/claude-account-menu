. Import-ClmModule claude-menu-archive, claude-self-version, claude-machine-settings, claude-registry,
  claude-backup-trust, claude-backup-restore, claude-text
$script:SaveExcludes = @("cache", "paste-cache", "session-env", "shell-snapshots", "ide", "*.lock", ".local/bin/*.exe") + $script:SkipConversations
$script:ArchiveRegistryName = ".claude-accounts.json"
$script:ArchiveNameTries = 1000

function Get-AccountItems {
  param($Accs)
  $names = @()
  foreach ($a in @(Select-ValidAccounts $Accs)) {
    $names += $a.Dir
    if ($a.Dir -eq ".claude") { $names += @(".claude.json", ".mcp.json") }
  }
  return $names
}

function Get-SaveItems {
  param($Accs)
  $h = $script:HomeDir
  $bin = Get-ChildItem -LiteralPath $script:ClmModuleDir -File -Recurse | Where-Object { $_.Name -match "^((clm|claude-.*)\.(cmd|ps1)|clm|clm\.version)$" } | ForEach-Object { ".local/bin/" + $_.FullName.Substring($script:ClmModuleDir.Length + 1).Replace("\", "/") }
  $names = @(Get-AccountItems $Accs) + @($bin)
  return @($names | Where-Object { Test-Path -LiteralPath (Join-Path $h $_) })
}

function New-RegistryStage {
  if (-not (Test-Path -LiteralPath $script:RegistryPath)) { return $null }
  $dir = Join-Path ([IO.Path]::GetTempPath()) ("claude-reg-" + [guid]::NewGuid().ToString("N"))
  $null = [IO.Directory]::CreateDirectory($dir)
  [IO.File]::Copy($script:RegistryPath, (Join-Path $dir $script:ArchiveRegistryName))
  return $dir
}

function Get-SaveExcludes {
  param($Accs)
  $ex = @($script:SaveExcludes)
  foreach ($acc in @(Select-ValidAccounts $Accs)) {
    $ex += $acc.Dir + "/skills/.*"
    if ($acc.Dir -eq ".claude") { continue }
    foreach ($s in $script:SharedDirs + $script:SharedFiles) { $ex += $acc.Dir + "/" + $s }
  }
  return $ex
}

function Get-FreeArchivePath {
  param([string]$Name, [string]$Ext)
  $dir = Get-DownloadsDir
  for ($n = 1; $n -le $script:ArchiveNameTries; $n++) {
    $path = Join-Path $dir ($Name + $Ext)
    if ($n -gt 1) { $path = Join-Path $dir ($Name + "-" + $n + $Ext) }
    try { [IO.File]::Open($path, "CreateNew", "Write", "None").Dispose(); return $path }
    catch { if (-not (Test-Path -LiteralPath $path)) { throw } }
  }
  throw (Get-ClmText "backup.save.noFreeName" @(($Name + $Ext), $dir))
}

function Save-Accounts {
  param([string]$Tag = "", $Accs = $null)
  if ($null -eq $Accs) { $Accs = @(Get-Accounts) }
  Initialize-Tar
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $name = "claude-comptes-" + $stamp
  if ($Tag) { $name = "claude-comptes-" + $Tag + "-" + $stamp }
  $zip = Get-FreeArchivePath $name (Get-ArchiveExtension $script:TarFlavor)
  Set-PrivateMode $zip
  $argv = @("-a", "-c", "-f", $zip, "-C", $script:HomeDir)
  $ex = @(Get-SaveExcludes $Accs)
  foreach ($x in $ex) { $argv += @("--exclude", $x) }
  $items = @(Get-SaveItems $Accs)
  $argv += $items
  $label = Get-ClmText "backup.tar.saving"
  if ($Tag) { $label = Get-ClmText "backup.tar.copyOfState" }
  $stage = New-RegistryStage
  if ($stage) { $argv += @("-C", $stage, $script:ArchiveRegistryName) }
  try { $warn = Invoke-Tar $argv (Measure-Entries $items $ex) $label }
  finally {
    if ($stage) { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue }
    if ([IO.File]::Exists($zip) -and ([IO.FileInfo]$zip).Length -eq 0) { [IO.File]::Delete($zip) }
  }
  if (-not (Test-Path -LiteralPath $zip)) { throw (Get-ClmText "backup.save.tarFailed" @(($warn -join " "))) }
  if ($warn.Count -gt 0 -and -not (Test-ArchiveIntact $zip)) {
    Remove-Item -LiteralPath $zip -Force
    throw (Get-ClmText "backup.save.unreadable" @((@($warn | Select-Object -First 3) -join " ")))
  }
  Set-PrivateMode $zip
  Add-BackupMark $zip
  $mb = [math]::Round((Get-Item -LiteralPath $zip).Length / 1MB)
  $res = Get-ClmText "backup.save.result" @($zip, (Get-ClmText "backup.size" @($mb)), (@($Accs | ForEach-Object { $_.Label }) -join ", "))
  if ($warn.Count -gt 0) { $res += Get-ClmText "backup.save.warnings" @($warn.Count) }
  return $res
}

function Get-Backups {
  return @(Get-ChildItem -LiteralPath (Get-DownloadsDir) -File | Where-Object { $_.Name -like "claude-comptes-*.zip" -or $_.Name -like "claude-comptes-*.tar.gz" } | Where-Object { Test-BackupListed $_ } | Sort-Object LastWriteTime -Descending)
}
