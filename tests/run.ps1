$ErrorActionPreference = "Stop"
$bin = Join-Path (Split-Path -Parent $PSScriptRoot) "bin"
$envNames = @("USERPROFILE", "HOME", "LOCALAPPDATA", "XDG_CACHE_HOME", "XDG_STATE_HOME", "XDG_CONFIG_HOME", "STATUSLINE_BG", "CLAUDE_CONFIG_DIR")
$savedEnv = @{}
foreach ($n in $envNames) { $savedEnv[$n] = [Environment]::GetEnvironmentVariable($n) }
$script:Sandbox = Join-Path ([IO.Path]::GetTempPath()) ("clm-tests-" + [guid]::NewGuid().ToString("N"))
$script:NoNetworkText = "reseau interdit pendant les tests"

function Stop-TestNetwork { throw $script:NoNetworkText }
Set-Alias -Name Invoke-WebRequest -Value Stop-TestNetwork
Set-Alias -Name Invoke-RestMethod -Value Stop-TestNetwork
$script:Passed = 0
$script:Failed = @()

function Assert-Equal {
  param($Expected, $Actual, [string]$Name)
  if (("" + $Expected) -ceq ("" + $Actual)) { $script:Passed++; return }
  $script:Failed += ($Name + " : attendu [" + $Expected + "], obtenu [" + $Actual + "]")
}

function Assert-Null {
  param($Actual, [string]$Name)
  if ($null -eq $Actual) { $script:Passed++; return }
  $script:Failed += ($Name + " : attendu null, obtenu [" + $Actual + "]")
}

function Assert-True {
  param([bool]$Value, [string]$Name)
  Assert-Equal $true $Value $Name
}

function Assert-Throws {
  param([scriptblock]$Action, [string]$Contains, [string]$Name)
  $msg = $null
  try { $null = & $Action } catch { $msg = $_.Exception.Message }
  if ($null -ne $msg -and $msg.Contains($Contains)) { $script:Passed++; return }
  $script:Failed += ($Name + " : attendu une erreur contenant [" + $Contains + "], obtenu [" + $msg + "]")
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
  $script:SyncKeyStoreOs = "Linux"
  . (Join-Path $bin "claude-usage.ps1")
  . (Join-Path $bin "claude-menu-view.ps1")
  . (Join-Path $bin "claude-menu-archive.ps1")
  . (Join-Path $bin "claude-update.ps1")
  . (Join-Path $bin "claude-self-update.ps1")
  . (Join-Path $bin "claude-statusline-seed.ps1")
  . (Join-Path $bin "claude-drive-sync.ps1")
  . (Join-Path $bin "claude-drive-watch.ps1")
  . (Join-Path $bin "claude-drive-cli.ps1")
  . (Join-Path $bin "claude-account-guard.ps1")
  Remove-Item Env:STATUSLINE_BG
  $script:SyncKeyStoreOs = "Linux"
  foreach ($checkFile in Get-ChildItem -LiteralPath $PSScriptRoot -Filter "*.checks.ps1" -Recurse | Sort-Object Name) {
    try { . $checkFile.FullName } catch { $script:Failed += ($checkFile.Name + " : exception " + $_.Exception.Message + " ligne " + $_.InvocationInfo.ScriptLineNumber) }
  }
} finally {
  foreach ($n in $envNames) { [Environment]::SetEnvironmentVariable($n, $savedEnv[$n]) }
  Remove-Item -LiteralPath $script:Sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

foreach ($f in $script:Failed) { Write-Host ("ECHEC " + $f) }
Write-Host ("" + $script:Passed + " reussis, " + $script:Failed.Count + " echecs (PowerShell " + $PSVersionTable.PSVersion + ", " + $script:OsName + ")")
if ($script:Failed.Count -gt 0) { exit 1 }
exit 0
