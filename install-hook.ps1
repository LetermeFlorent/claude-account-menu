param([Parameter(Mandatory = $true)][string]$HookCommand)
$ErrorActionPreference = "Stop"
$homeDir = $env:USERPROFILE
if (-not $homeDir) { $homeDir = $env:HOME }
$readArgs = @{}
if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey("DateKind")) { $readArgs["DateKind"] = "String" }
$dirs = @(Join-Path $homeDir ".claude") + @(Get-ChildItem -LiteralPath $homeDir -Directory -Force -Filter ".claude-compte*" | ForEach-Object { $_.FullName })
foreach ($d in $dirs) {
  $f = Join-Path $d "settings.json"
  if (-not (Test-Path -LiteralPath $f)) { continue }
  $raw = [IO.File]::ReadAllText($f)
  if ($raw.Contains("claude-statusline-seed.ps1")) { continue }
  Copy-Item -LiteralPath $f -Destination ($f + ".bak-seed") -Force
  $j = $raw | ConvertFrom-Json @readArgs
  $entry = [PSCustomObject]@{ matcher = "startup"; hooks = @([PSCustomObject]@{ type = "command"; command = $HookCommand; timeout = 15 }) }
  if (-not $j.PSObject.Properties["hooks"]) { $j | Add-Member -NotePropertyName hooks -NotePropertyValue ([PSCustomObject]@{}) }
  if ($j.hooks.PSObject.Properties["SessionStart"]) { $j.hooks.SessionStart = @($j.hooks.SessionStart) + $entry }
  else { $j.hooks | Add-Member -NotePropertyName SessionStart -NotePropertyValue @($entry) }
  [IO.File]::WriteAllText($f, ($j | ConvertTo-Json -Depth 30), (New-Object Text.UTF8Encoding($false)))
  Write-Host ("rafraichissement des quotas de la barre d'etat actif dans " + $f)
}
