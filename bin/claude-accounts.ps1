if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-platform.ps1")) { . (Join-Path $PSScriptRoot "claude-platform.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-credentials.ps1")) { . (Join-Path $PSScriptRoot "claude-credentials.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-account-add.ps1")) { . (Join-Path $PSScriptRoot "claude-account-add.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-state.ps1")) { . (Join-Path $PSScriptRoot "claude-state.ps1") }
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

function Get-Accounts {
  if (Test-Path -LiteralPath $script:RegistryPath) {
    try {
      $data = Get-Content -LiteralPath $script:RegistryPath -Raw | ConvertFrom-Json
      return @($data | ForEach-Object { $_ })
    } catch {
      Copy-Item -LiteralPath $script:RegistryPath -Destination ($script:RegistryPath + ".bad") -Force
    }
  }
  $list = @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" })
  foreach ($n in 2..9) {
    $d = ".claude-compte" + $n
    if (Test-Path -LiteralPath (Join-Path $script:HomeDir $d)) { $list += [PSCustomObject]@{ Label = "compte" + $n; Dir = $d } }
  }
  Save-Registry $list
  return $list
}

function Save-Registry {
  param($List)
  ConvertTo-Json -InputObject @($List) -Depth 3 | Set-Content -LiteralPath $script:RegistryPath -Encoding UTF8
}

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
  try { $raw = Get-Content -LiteralPath (Get-AccountConfigFile $Acc) -Raw -ErrorAction Stop } catch { return "" }
  if ($raw -match '"oauthAccount"\s*:\s*\{[^}]*?"emailAddress"\s*:\s*"([^"]+)"') { return $Matches[1] }
  return ""
}

function Invoke-InAccountEnv {
  param($Acc, [scriptblock]$Action)
  $prev = $env:CLAUDE_CONFIG_DIR
  try {
    if ($Acc.Dir -eq ".claude") { Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue }
    else { $env:CLAUDE_CONFIG_DIR = Get-AccountPath $Acc }
    & $Action
  } finally {
    if ($null -eq $prev) { Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue } else { $env:CLAUDE_CONFIG_DIR = $prev }
  }
}

function Invoke-AsAccount {
  param($Acc, [object[]]$ArgList)
  Invoke-InAccountEnv $Acc { & $script:ClaudeExe @ArgList }
}

function Repair-SharedLinks {
  param($Acc, [switch]$Force)
  if ($Acc.Dir -eq ".claude") { return }
  $main = Join-Path $script:HomeDir ".claude"
  $dir = Get-AccountPath $Acc
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  foreach ($d in $script:SharedDirs) {
    $src = Join-Path $main $d; $dst = Join-Path $dir $d
    if (-not (Test-Path -LiteralPath $src)) { continue }
    if ((Test-Path -LiteralPath $dst) -and -not (Get-Item -LiteralPath $dst -Force).LinkType) {
      try { Rename-Item -LiteralPath $dst -NewName ($d + ".bak-sync") -ErrorAction Stop } catch { continue }
    }
    if (-not (Test-Path -LiteralPath $dst)) { New-Item -ItemType (Get-DirLinkType) -Path $dst -Target $src | Out-Null }
  }
  foreach ($f in $script:SharedFiles) {
    $src = Join-Path $main $f; $dst = Join-Path $dir $f
    if (-not (Test-Path -LiteralPath $src)) { continue }
    if ((Test-Path -LiteralPath $dst) -and ($Force -or -not (Test-SameFile $src $dst))) {
      if (-not $Force -and [IO.File]::GetLastWriteTimeUtc($dst) -gt [IO.File]::GetLastWriteTimeUtc($src)) {
        [IO.File]::WriteAllBytes($src, [IO.File]::ReadAllBytes($dst))
      }
      Remove-Item -LiteralPath $dst -Force
    }
    if (-not (Test-Path -LiteralPath $dst)) { New-Item -ItemType HardLink -Path $dst -Target $src | Out-Null }
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
