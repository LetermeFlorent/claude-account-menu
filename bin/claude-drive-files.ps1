if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-accounts.ps1")) { . (Join-Path $PSScriptRoot "claude-accounts.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-menu-save.ps1")) { . (Join-Path $PSScriptRoot "claude-menu-save.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-json.ps1")) { . (Join-Path $PSScriptRoot "claude-json.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-machine-settings.ps1")) { . (Join-Path $PSScriptRoot "claude-machine-settings.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-drive-patterns.ps1")) { . (Join-Path $PSScriptRoot "claude-drive-patterns.ps1") }
$script:SyncLocalOnly = @("*/chrome-bidi/profils", "node_modules", "file-history") + @(foreach ($p in $script:SkipConversations) { "*/" + $p })
$script:SyncExtraExcludes = @("*.bak-sync", "*.conflit-*", ".credentials.json", "*.tmp") + $script:SyncLocalOnly
$script:RegistryName = ".claude-accounts.json"

function Get-SyncRootPath {
  param([string]$Root, [string]$Rel)
  if ($Rel -eq $script:RegistryName -or $Rel.StartsWith($script:RegistryName + ".")) { return $script:RegistryPath + $Rel.Substring($script:RegistryName.Length) }
  return Join-Path $Root ($Rel.Replace("/", [IO.Path]::DirectorySeparatorChar))
}

function Get-SyncPatterns {
  param($Accs)
  return @(Get-SaveExcludes $Accs) + $script:SyncExtraExcludes
}

function Get-SyncRoots {
  param($Accs)
  return @(Get-AccountItems $Accs) + @($script:RegistryName)
}

$script:MachinePathHint = New-Object regex '^(?:\.claude[^/]*/(?:settings|\.claude)\.json|\.(?:claude|mcp)\.json)$',([Text.RegularExpressions.RegexOptions]"IgnoreCase, CultureInvariant")
$script:StopCheckDirs = 16

function ConvertTo-HexText {
  param([byte[]]$Bytes)
  return -join ($Bytes | ForEach-Object { $_.ToString("x2") })
}

function Get-FileMd5 {
  param([string]$Path)
  $fs = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
  $md5 = [Security.Cryptography.MD5]::Create()
  try { return ConvertTo-HexText ($md5.ComputeHash($fs)) } finally { $md5.Dispose(); $fs.Dispose() }
}

function Get-SyncBytes {
  param([string]$Rel, [string]$Path)
  $bytes = Read-SharedBytes $Path
  $kind = Get-MachineKind $Rel
  if ($null -ne $kind) { return ,(Convert-SettingsBytes $bytes -Kind $kind) }
  return ,$bytes
}

function Get-SyncMd5 {
  param([string]$Rel, [string]$Path)
  if (-not (Test-MachineSettingsPath $Rel)) { return Get-FileMd5 $Path }
  $md5 = [Security.Cryptography.MD5]::Create()
  try { return ConvertTo-HexText ($md5.ComputeHash((Get-SyncBytes $Rel $Path))) } finally { $md5.Dispose() }
}

function ConvertTo-UnixSeconds {
  param([DateTime]$Utc)
  return [long]([DateTimeOffset]::new([DateTime]::SpecifyKind($Utc, [DateTimeKind]::Utc))).ToUnixTimeSeconds()
}

function Add-LocalFile {
  param($Result, [string]$Rel, [IO.FileInfo]$Info, $Base)
  $m = ConvertTo-UnixSeconds $Info.LastWriteTimeUtc
  $b = $Base[$Rel]
  $md5 = $null
  if ($null -ne $b -and -not (Test-MachineSettingsPath $Rel) -and [long]$b.Size -eq $Info.Length -and [long]$b.M -eq $m) { $md5 = [string]$b.Md5 }
  if (-not $md5) {
    try { $md5 = Get-SyncMd5 $Rel $Info.FullName } catch { $Result.Skipped.Add($Rel); return }
  }
  $Result.Files[$Rel] = @{ Md5 = $md5; M = $m; Size = $Info.Length; Full = $Info.FullName }
}

function Test-SyncStop {
  param($Ctl, [long]$DeadlineMs)
  if ($null -ne $Ctl -and $Ctl.Stop) { return $true }
  return $DeadlineMs -gt 0 -and [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() -ge $DeadlineMs
}

function Get-LocalFiles {
  param([string]$Root, $Roots, $Patterns, $Base, $Ctl = $null, [long]$DeadlineMs = 0)
  $res = @{ Files = (New-PathMap); Skipped = (New-Object 'System.Collections.Generic.List[string]'); Stopped = $false }
  $stack = New-Object Collections.Stack
  $rx = Get-ExcludeRegex $Patterns
  foreach ($r in $Roots) {
    if ($rx.IsMatch($r)) { continue }
    $full = Get-SyncRootPath $Root $r
    if ([IO.File]::Exists($full)) { Add-LocalFile $res $r ([IO.FileInfo]$full) $Base }
    elseif ([IO.Directory]::Exists($full)) { $stack.Push(@($r, $full)) }
  }
  $dirs = 0
  while ($stack.Count -gt 0) {
    if (($dirs++ % $script:StopCheckDirs) -eq 0 -and (Test-SyncStop $Ctl $DeadlineMs)) { $res.Stopped = $true; break }
    $d = $stack.Pop()
    try { $items = ([IO.DirectoryInfo]$d[1]).GetFileSystemInfos() } catch { $res.Skipped.Add($d[0]); continue }
    foreach ($i in $items) {
      $rel = $d[0] + "/" + $i.Name
      if ($rx.IsMatch($rel)) { continue }
      if (-not (Test-SafeSyncPath $rel)) { $res.Skipped.Add($rel); continue }
      if ($i.Attributes -band [IO.FileAttributes]::ReparsePoint) { $res.Skipped.Add($rel); continue }
      if ($i -is [IO.DirectoryInfo]) { $stack.Push(@($rel, $i.FullName)); continue }
      $b = $Base[$rel]
      if ($null -ne $b -and [long]$b.Size -eq $i.Length -and -not $script:MachinePathHint.IsMatch($rel)) {
        $m = ([DateTimeOffset]$i.LastWriteTimeUtc).ToUnixTimeSeconds()
        if ([long]$b.M -eq $m) { $res.Files[$rel] = @{ Md5 = [string]$b.Md5; M = $m; Size = $i.Length; Full = $i.FullName }; continue }
      }
      Add-LocalFile $res $rel $i $Base
    }
  }
  return $res
}

$script:SyncKeptDepth = 2

function Remove-SyncLocalFile {
  param([string]$Rel)
  $full = Get-SyncLocalPath $Rel
  if (Test-Path -LiteralPath $full) { Remove-Item -LiteralPath $full -Force -ErrorAction Stop }
  $parts = $Rel.Split("/")
  for ($n = $parts.Count - 1; $n -gt $script:SyncKeptDepth; $n--) {
    $dir = Get-SyncLocalPath ($parts[0..($n - 1)] -join "/")
    if (-not [IO.Directory]::Exists($dir) -or @([IO.Directory]::GetFileSystemEntries($dir)).Count -gt 0) { return }
    try { [IO.Directory]::Delete($dir) } catch [IO.IOException] { return }
  }
}
