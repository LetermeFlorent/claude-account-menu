$ErrorActionPreference = "Stop"
. (Join-Path (Join-Path $PSScriptRoot "bin") "claude-machine-settings.ps1")
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
    [IO.File]::WriteAllText($f, $fixed, (New-Object Text.UTF8Encoding($false)))
    Write-Host ("commande du hook de la barre d'etat remplacee dans " + $f)
    continue
  }
  $j = $raw | ConvertFrom-Json @readArgs
  $entry = [PSCustomObject]@{ matcher = "startup"; hooks = @([PSCustomObject]@{ type = "command"; command = $hookCommand; timeout = 15 }) }
  if (-not $j.PSObject.Properties["hooks"]) { $j | Add-Member -NotePropertyName hooks -NotePropertyValue ([PSCustomObject]@{}) }
  if ($j.hooks.PSObject.Properties["SessionStart"]) { $j.hooks.SessionStart = @($j.hooks.SessionStart) + $entry }
  else { $j.hooks | Add-Member -NotePropertyName SessionStart -NotePropertyValue @($entry) }
  [IO.File]::WriteAllText($f, ($j | ConvertTo-Json -Depth 30), (New-Object Text.UTF8Encoding($false)))
  Write-Host ("rafraichissement des quotas de la barre d'etat actif dans " + $f)
}
