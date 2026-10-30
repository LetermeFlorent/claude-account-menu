$ErrorActionPreference = "Stop"
. (Join-Path (Join-Path $PSScriptRoot "bin") "claude-import.ps1")
. (Join-Path (Join-Path $PSScriptRoot "bin") "machine/claude-machine-settings.ps1")
. Import-ClmModule claude-text
$hookCommand = Get-SeedHookCommand $script:OsName
$homeDir = $env:USERPROFILE
if (-not $homeDir) { $homeDir = $env:HOME }
$readArgs = @{}
if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey("DateKind")) { $readArgs["DateKind"] = "String" }
$dirs = @(Join-Path $homeDir ".claude") + @(Get-ChildItem -LiteralPath $homeDir -Directory -Force -Filter ".claude-compte*" | ForEach-Object { $_.FullName })
foreach ($d in $dirs) {
  $f = Join-Path $d "settings.json"
  if (-not (Test-Path -LiteralPath $f)) { continue }
  $raw = [IO.File]::ReadAllText($f)
  $fixed = Set-SeedCommand $raw $hookCommand
  if ($fixed -ceq $raw -and [regex]::IsMatch($raw, $script:SeedTokenPattern)) { continue }
  Copy-Item -LiteralPath $f -Destination ($f + ".bak-seed") -Force
  if ($fixed -cne $raw) {
    Write-TextFileAtomic $f $fixed
    Write-Host (Get-ClmText "install.hookReplaced" @($f))
    continue
  }
  $j = $raw | ConvertFrom-Json @readArgs
  $entry = [PSCustomObject]@{ matcher = "startup"; hooks = @([PSCustomObject]@{ type = "command"; command = $hookCommand; timeout = 15 }) }
  if (-not $j.PSObject.Properties["hooks"]) { $j | Add-Member -NotePropertyName hooks -NotePropertyValue ([PSCustomObject]@{}) }
  if ($j.hooks.PSObject.Properties["SessionStart"]) { $j.hooks.SessionStart = @($j.hooks.SessionStart) + $entry }
  else { $j.hooks | Add-Member -NotePropertyName SessionStart -NotePropertyValue @($entry) }
  Write-TextFileAtomic $f ($j | ConvertTo-Json -Depth 30)
  Write-Host (Get-ClmText "install.hookQuota" @($f))
}
