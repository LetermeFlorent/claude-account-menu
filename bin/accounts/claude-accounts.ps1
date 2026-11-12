. Import-ClmModule claude-platform, claude-credentials, claude-account-add, claude-state, claude-registry, claude-account-email, claude-text, claude-network, claude-memory
$script:HomeDir = Get-HomeDir
$script:RegistryPath = Get-StatePath "accounts.json"
$script:ClaudeExe = Find-ClaudeExe

function Get-ClaudeVersion {
  try { $v = "" + (& $script:ClaudeExe --version 2>$null) } catch { $v = "" }
  if ($v -match "(\d+\.\d+\.\d+)") { return $Matches[1] }
  return "1.0.0"
}
$script:SharedDirs = @("agents", "commands", "hooks", "plugins", "rules", "skills")
$script:SharedFiles = @("ANTI-EMPREINTE.md", "CLAUDE.md", "settings.local.json", "statusline.json")

function Get-AccountPath {
  param($Acc)
  return Join-Path $script:HomeDir $Acc.Dir
}

function Get-AccountConfigFile {
  param($Acc)
  if ($Acc.Dir -eq ".claude") { return Join-Path $script:HomeDir ".claude.json" }
  return Join-Path (Get-AccountPath $Acc) ".claude.json"
}

function Get-AccountEmail {
  param($Acc)
  return Read-AccountEmail (Get-AccountConfigFile $Acc)
}

function Test-DuplicateAccountEmail {
  param($Acc)
  $mail = Get-AccountEmail $Acc
  if ($mail -eq "") { return $false }
  foreach ($o in @(Get-Accounts)) { if ($o.Dir -ne $Acc.Dir -and (Get-AccountEmail $o) -eq $mail) { return $true } }
  return $false
}

function Clear-AccountLogin {
  param($Acc)
  $dir = Get-AccountPath $Acc
  if ($script:OsName -eq "MacOS") {
    $kd = $null
    if ($Acc.Dir -ne ".claude") { $kd = $dir }
    Remove-KeychainCredential $kd
  }
  Remove-Item -LiteralPath (Join-Path $dir ".credentials.json") -Force -ErrorAction SilentlyContinue
  $file = Get-AccountConfigFile $Acc
  $cfg = Read-JsonFile $file
  if ($null -ne $cfg -and @($cfg.Keys) -contains "oauthAccount") { $null = $cfg.Remove("oauthAccount"); Write-JsonFile $file $cfg }
}

function Test-LoginLocked {
  param($Acc)
  if ($env:CLM_ALLOW_LOGIN -eq "1" -or (Get-AccountEmail $Acc) -eq "") { return $false }
  return $null -ne (Read-AccountCredential $Acc)
}

function Invoke-InAccountEnv {
  param($Acc, [scriptblock]$Action)
  $prev = $env:CLAUDE_CONFIG_DIR
  $prevLogin = $env:DISABLE_LOGIN_COMMAND
  try {
    if ($Acc.Dir -eq ".claude") { Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue }
    else { $env:CLAUDE_CONFIG_DIR = Get-AccountPath $Acc }
    if (Test-LoginLocked $Acc) { $env:DISABLE_LOGIN_COMMAND = "1" }
    & $Action
  } finally {
    if ($null -eq $prev) { Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue } else { $env:CLAUDE_CONFIG_DIR = $prev }
    if ($null -eq $prevLogin) { Remove-Item Env:DISABLE_LOGIN_COMMAND -ErrorAction SilentlyContinue } else { $env:DISABLE_LOGIN_COMMAND = $prevLogin }
  }
}

function Invoke-AsAccount {
  param($Acc, [object[]]$ArgList)
  $null = Clear-ClmMemory
  Invoke-InAccountEnv $Acc { & $script:ClaudeExe @ArgList }
}

function Repair-SharedLinks {
  param($Acc, [switch]$Force)
  if ($Acc.Dir -eq ".claude") { return }
  $main = Join-Path $script:HomeDir ".claude"
  $dir = Get-AccountPath $Acc
  foreach ($root in @($main, $dir)) {
    if (Test-ReparsePath $root) { Write-Warning (Get-ClmText "accounts.link.skipped" @($root)); return }
  }
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  foreach ($d in $script:SharedDirs) {
    $src = Join-Path $main $d; $dst = Join-Path $dir $d
    if (-not (Test-Path -LiteralPath $src)) { continue }
    if ((Test-Path -LiteralPath $dst) -and -not (Get-Item -LiteralPath $dst -Force).LinkType) {
      try { Merge-SharedDir $dst $src $Acc.Label; Move-Item -LiteralPath $dst -Destination (Get-FreeBackupPath ($dst + ".bak-sync") $Acc.Label) -ErrorAction Stop } catch { continue }
    }
    if (-not (Test-Path -LiteralPath $dst)) { New-Item -ItemType (Get-DirLinkType) -Path $dst -Target $src | Out-Null }
  }
  foreach ($f in $script:SharedFiles) {
    $src = Join-Path $main $f; $dst = Join-Path $dir $f
    if (-not (Test-Path -LiteralPath $src)) { continue }
    if ((Test-Path -LiteralPath $dst) -and ($Force -or -not (Test-SameFile $src $dst))) {
      if (-not $Force) { Save-DivergedCopy $src $dst $Acc.Label }
      Remove-Item -LiteralPath $dst -Force
    }
    if (-not (Test-Path -LiteralPath $dst)) { New-Item -ItemType HardLink -Path $dst -Target $src | Out-Null }
  }
}

function Get-FreeBackupPath {
  param([string]$Path, [string]$Label)
  if (-not (Test-Path -LiteralPath $Path)) { return $Path }
  $base = $Path -replace "\.bak-sync$", ""
  return $base + ".conflit-" + ($Label -replace "[^A-Za-z0-9_-]", "_") + "-" + [DateTime]::UtcNow.ToString("yyyyMMddHHmmssfff")
}

function Save-DivergedCopy {
  param([string]$Main, [string]$Copy, [string]$Label)
  $a = [IO.File]::ReadAllBytes($Main); $b = [IO.File]::ReadAllBytes($Copy)
  if ([Linq.Enumerable]::SequenceEqual($a, $b)) { return }
  $copyNewer = [IO.File]::GetLastWriteTimeUtc($Copy) -gt [IO.File]::GetLastWriteTimeUtc($Main)
  $lost = $b
  if ($copyNewer) { $lost = $a }
  [IO.File]::WriteAllBytes((Get-FreeBackupPath ($Main + ".bak-sync") $Label), $lost)
  if ($copyNewer) { [IO.File]::WriteAllBytes($Main, $b) }
}

function Merge-SharedDir {
  param([string]$From, [string]$Into, [string]$Label)
  foreach ($f in [IO.Directory]::GetFiles($From, "*", "AllDirectories")) {
    $target = Join-Path $Into $f.Substring($From.Length).TrimStart("\", "/")
    if ([IO.File]::Exists($target)) {
      if ([Linq.Enumerable]::SequenceEqual([IO.File]::ReadAllBytes($f), [IO.File]::ReadAllBytes($target))) { continue }
      $target = Get-FreeBackupPath ($target + ".bak-sync") $Label
    }
    $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
    [IO.File]::Copy($f, $target)
  }
}

function Test-SameFile {
  param([string]$A, [string]$B)
  $links = @((Get-Item -LiteralPath $A -Force).Target | Where-Object { $_ })
  if ($links.Count -gt 0) { return @($links | Where-Object { (ConvertTo-PathKey $_) -eq (ConvertTo-PathKey $B) }).Count -gt 0 }
  if ($script:OsName -eq "Windows") {
    $drive = [IO.Path]::GetPathRoot($A).TrimEnd("\\")
    $links = @(& fsutil hardlink list $A 2>$null | ForEach-Object { $drive + $_ })
    return @($links | Where-Object { (ConvertTo-PathKey $_) -eq (ConvertTo-PathKey $B) }).Count -gt 0
  }
  return (Get-FileHash -LiteralPath $A).Hash -eq (Get-FileHash -LiteralPath $B).Hash
}
