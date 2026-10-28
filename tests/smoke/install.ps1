$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$onWindows = [IO.Path]::DirectorySeparatorChar -eq "\"
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ("clm-smoke-" + [guid]::NewGuid().ToString("N"))
$claudeDir = Join-Path $sandbox ".claude"
New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $claudeDir "settings.json"), "{}")
$env:HOME = $sandbox
$env:USERPROFILE = $sandbox
$env:XDG_STATE_HOME = Join-Path $sandbox ".local/state"
$env:XDG_CACHE_HOME = Join-Path $sandbox ".cache"
if ($onWindows) { $env:LOCALAPPDATA = Join-Path $sandbox "AppData\Local" }
$failures = @()

function Invoke-Installer {
  if ($onWindows) { & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "install.ps1") }
  else { & sh (Join-Path $repo "install.sh") }
  if ($LASTEXITCODE -ne 0) { throw ("installer exit code " + $LASTEXITCODE) }
}

function Invoke-Clm {
  param([string[]]$Arguments)
  $bin = Join-Path $sandbox ".local/bin"
  if ($onWindows) { $out = & cmd /c (Join-Path $bin "clm.cmd") @Arguments 2>&1 }
  else { $out = & (Join-Path $bin "clm") @Arguments 2>&1 }
  return @{ Code = $LASTEXITCODE; Text = ($out | Out-String) }
}

Invoke-Installer
Invoke-Installer
$settings = [IO.File]::ReadAllText((Join-Path $claudeDir "settings.json"))
$hookCount = ([regex]::Matches($settings, "claude-statusline-seed\.ps1")).Count
if ($hookCount -ne 1) { $failures += ("hook written " + $hookCount + " times") }

$help = Invoke-Clm @("--help")
if ($help.Code -ne 0) { $failures += ("clm --help exit " + $help.Code + ": " + $help.Text) }
if ($help.Text -notmatch "--list") { $failures += "clm --help does not list --list" }

$list = Invoke-Clm @("--list")
if ($list.Code -ne 0) { $failures += ("clm --list exit " + $list.Code + ": " + $list.Text) }
if ($list.Text -notmatch "\.claude") { $failures += ("clm --list misses .claude: " + $list.Text) }

Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
if ($failures.Count -gt 0) {
  $failures | ForEach-Object { Write-Host $_ }
  exit 1
}
Write-Host "install smoke test passed"
