. (Join-Path $PSScriptRoot "claude-accounts.ps1")
. (Join-Path $PSScriptRoot "claude-menu-save.ps1")
. (Join-Path $PSScriptRoot "claude-json.ps1")
. (Join-Path $PSScriptRoot "claude-machine-settings.ps1")
$script:SyncLocalOnly = @("*/chrome-bidi/profils", "node_modules", "file-history") + @(foreach ($p in $script:SkipConversations) { "*/" + $p })
$script:SyncExtraExcludes = @("*.bak-sync", "*.conflit-*", ".credentials.json", "*.tmp") + $script:SyncLocalOnly
$script:RegistryName = ".claude-accounts.json"

function Get-SyncPatterns {
  param($Accs)
  return @(Get-SaveExcludes $Accs) + $script:SyncExtraExcludes
}

function Get-SyncRoots {
  param($Accs)
  return @(Get-AccountItems $Accs) + @($script:RegistryName)
}

$script:ExcludeRegexMemo = New-PathMap
$script:ExcludeRegexOptions = [Text.RegularExpressions.RegexOptions]"IgnoreCase, CultureInvariant, Singleline"

function ConvertTo-WildcardRegex {
  param([string]$Pattern, [string]$Star, [string]$One)
  $sb = New-Object Text.StringBuilder
  for ($i = 0; $i -lt $Pattern.Length; $i++) {
    $ch = [string]$Pattern[$i]
    $close = -1
    if ($ch -eq "[") { $close = $Pattern.IndexOf("]", $i + 1) }
    if ($ch -eq "``" -and $i + 1 -lt $Pattern.Length) { $i++; [void]$sb.Append([regex]::Escape([string]$Pattern[$i])) }
    elseif ($ch -eq "*") { [void]$sb.Append($Star) }
    elseif ($ch -eq "?") { [void]$sb.Append($One) }
    elseif ($close -gt $i + 1) { [void]$sb.Append("[" + $Pattern.Substring($i + 1, $close - $i - 1).Replace("\", "\\").Replace("[", "\[").Replace("^", "\^") + "]"); $i = $close }
    else { [void]$sb.Append([regex]::Escape($ch)) }
  }
  return $sb.ToString()
}

function Get-ExcludeRegex {
  param($Patterns)
  $key = @($Patterns) -join "`n"
  if ($script:ExcludeRegexMemo.ContainsKey($key)) { return $script:ExcludeRegexMemo[$key] }
  $segments = New-Object 'System.Collections.Generic.List[string]'
  $paths = New-Object 'System.Collections.Generic.List[string]'
  foreach ($p in @($Patterns)) {
    if ($p.Contains("/")) { $paths.Add((ConvertTo-WildcardRegex $p ".*" ".")) }
    else { $segments.Add((ConvertTo-WildcardRegex $p "[^/]*" "[^/]")) }
  }
  $parts = @()
  if ($segments.Count -gt 0) { $parts += "(?:^|/)(?:" + ($segments -join "|") + ")(?:/|$)" }
  if ($paths.Count -gt 0) { $parts += "^(?:" + ($paths -join "|") + ")(?:/.*)?$" }
  if ($parts.Count -eq 0) { $parts = @("(?!)") }
  $rx = New-Object regex ($parts -join "|"), $script:ExcludeRegexOptions
  $script:ExcludeRegexMemo[$key] = $rx
  return $rx
}

function Test-SyncExcluded {
  param([string]$Rel, $Patterns)
  return (Get-ExcludeRegex $Patterns).IsMatch($Rel)
}

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
  if (Test-MachineSettingsPath $Rel) { return ,(Convert-SettingsBytes $bytes) }
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
    $full = Join-Path $Root $r
    if ([IO.File]::Exists($full)) { Add-LocalFile $res $r ([IO.FileInfo]$full) $Base }
    elseif ([IO.Directory]::Exists($full)) { $stack.Push(@($r, $full)) }
  }
  while ($stack.Count -gt 0) {
    if (Test-SyncStop $Ctl $DeadlineMs) { $res.Stopped = $true; break }
    $d = $stack.Pop()
    try { $items = ([IO.DirectoryInfo]$d[1]).GetFileSystemInfos() } catch { $res.Skipped.Add($d[0]); continue }
    foreach ($i in $items) {
      $rel = $d[0] + "/" + $i.Name
      if ($rx.IsMatch($rel)) { continue }
      if ($i.Attributes -band [IO.FileAttributes]::ReparsePoint) { $res.Skipped.Add($rel); continue }
      if ($i -is [IO.DirectoryInfo]) { $stack.Push(@($rel, $i.FullName)) }
      else { Add-LocalFile $res $rel $i $Base }
    }
  }
  return $res
}
