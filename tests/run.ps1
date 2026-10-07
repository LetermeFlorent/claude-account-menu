$ErrorActionPreference = "Stop"
$bin = Join-Path (Split-Path -Parent $PSScriptRoot) "bin"
$envNames = @("USERPROFILE", "HOME", "LOCALAPPDATA", "XDG_CACHE_HOME", "XDG_STATE_HOME", "XDG_CONFIG_HOME", "STATUSLINE_BG", "CLAUDE_CONFIG_DIR")
$savedEnv = @{}
foreach ($n in $envNames) { $savedEnv[$n] = [Environment]::GetEnvironmentVariable($n) }
$script:Sandbox = Join-Path ([IO.Path]::GetTempPath()) ("clm-tests-" + [guid]::NewGuid().ToString("N"))
$script:Passed = 0
$script:Failed = @()

function Assert-Equal {
  param($Expected, $Actual, [string]$Name)
  if (("" + $Expected) -ceq ("" + $Actual)) { $script:Passed++; return }
  $script:Failed += ($Name + " : attendu [" + $Expected + "], obtenu [" + $Actual + "]")
}

function Assert-Null {
  param($Actual, [string]$Name)
  if ($Actual -eq $null) { $script:Passed++; return }
  $script:Failed += ($Name + " : attendu null, obtenu [" + $Actual + "]")
}

function Assert-True {
  param([bool]$Value, [string]$Name)
  Assert-Equal $true $Value $Name
}

function New-SandboxFile {
  param([string]$Rel, [string]$Text)
  $p = [IO.Path]::Combine($script:Sandbox, $Rel)
  $d = Split-Path -Parent $p
  if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
  [IO.File]::WriteAllText($p, $Text, (New-Object Text.UTF8Encoding($false)))
  return $p
}

try {
  New-Item -ItemType Directory -Path $script:Sandbox | Out-Null
  foreach ($n in $envNames) { [Environment]::SetEnvironmentVariable($n, $null) }
  $env:USERPROFILE = $script:Sandbox
  $env:HOME = $script:Sandbox
  $env:LOCALAPPDATA = Join-Path $script:Sandbox "AppData"
  $env:STATUSLINE_BG = "dark"
  . (Join-Path $bin "claude-usage.ps1")
  . (Join-Path $bin "claude-menu-view.ps1")
  . (Join-Path $bin "claude-menu-archive.ps1")
  . (Join-Path $bin "claude-update.ps1")
  . (Join-Path $bin "claude-statusline-seed.ps1")
  Remove-Item Env:STATUSLINE_BG
  foreach ($t in Get-ChildItem -LiteralPath $PSScriptRoot -Filter "*.checks.ps1" | Sort-Object Name) {
    try { . $t.FullName } catch { $script:Failed += ($t.Name + " : exception " + $_.Exception.Message + " ligne " + $_.InvocationInfo.ScriptLineNumber) }
  }
} finally {
  foreach ($n in $envNames) { [Environment]::SetEnvironmentVariable($n, $savedEnv[$n]) }
  Remove-Item -LiteralPath $script:Sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

foreach ($f in $script:Failed) { Write-Host ("ECHEC " + $f) }
Write-Host ("" + $script:Passed + " reussis, " + $script:Failed.Count + " echecs (PowerShell " + $PSVersionTable.PSVersion + ", " + $script:OsName + ")")
if ($script:Failed.Count -gt 0) { exit 1 }
exit 0
