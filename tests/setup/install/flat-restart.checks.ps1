. (Join-Path (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "race") "race-helpers.ps1")
. Import-ClmModule claude-self-copy
$frRoot = Join-Path $script:Sandbox "flat-restart"
$frBin = Join-Path $frRoot "bin"
$frOld = "1111111111111111111111111111111111111111 1760000000 1"
$frNew = "2222222222222222222222222222222222222222 1770000000 2"
$frEntries = @("claude-import.ps1", "claude-menu.ps1", "claude-statusline-seed.ps1", "claude-drive-watcher.ps1")
$frEncoding = New-Object Text.UTF8Encoding($false)

function Write-FlatCopy {
  param([string]$Source, [string]$Target)
  foreach ($rel in Get-ClmTreeFiles $Source) {
    $full = [IO.Path]::Combine($Source, $rel)
    $name = [IO.Path]::GetFileName($rel)
    $dest = [IO.Path]::Combine($Target, $rel)
    if ($name -like "claude-*.ps1") { $dest = [IO.Path]::Combine($Target, $name) }
    $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dest))
    $text = [IO.File]::ReadAllText($full).Replace('"../../claude-import.ps1"', '"claude-import.ps1"').Replace('"../claude-import.ps1"', '"claude-import.ps1"')
    if ($name -eq "claude-import.ps1") { $text = [regex]::Replace($text, '(?m)^\$script:ClmModuleFolders = .*$', { param($m) '$script:ClmModuleFolders = @()' }) }
    [IO.File]::WriteAllText($dest, $text, $frEncoding)
  }
  [IO.File]::WriteAllText([IO.Path]::Combine($Target, "clm.version"), $frOld + "`n")
}

function Get-FlatLeftovers {
  param([string]$Target)
  return @(Get-ChildItem -LiteralPath $Target -Filter "claude-*.ps1" -File | Where-Object { $frEntries -notcontains $_.Name } | ForEach-Object { $_.Name })
}

function Get-TreeMismatch {
  param([string]$Source, [string]$Target)
  return @(foreach ($rel in Get-ClmTreeFiles $Source) {
    $dest = [IO.Path]::Combine($Target, $rel)
    if ($rel -eq "clm") { continue }
    if (-not [IO.File]::Exists($dest) -or -not (Test-ClmSameFile ([IO.Path]::Combine($Source, $rel)) $dest)) { $rel }
  })
}

Write-FlatCopy $bin $frBin
Assert-True ((Get-FlatLeftovers $frBin).Count -gt 100) "ancien clm a plat : la copie de depart est bien a plat"

$frOldClm = [PowerShell]::Create()
try {
  [void]$frOldClm.AddScript('param($Bin) . ([IO.Path]::Combine($Bin, "claude-import.ps1")); $script:ClmOnce = New-Object "System.Collections.Generic.HashSet[string]"; . Import-ClmModule claude-ui-loader, claude-lazy-load; $script:FlatUsage = Get-ClmModulePath "claude-usage"').AddArgument($frBin)
  [void]$frOldClm.Invoke()
  $frLoadErrors = @($frOldClm.Streams.Error | ForEach-Object { $_.ToString() }) -join " | "
  Assert-Equal "" $frLoadErrors "ancien clm a plat : demarre sans erreur avant la mise a jour"

  Install-ClmFiles $bin $frBin $frNew @("clm")
  Assert-Equal "" ((Get-FlatLeftovers $frBin) -join ",") "installation sur un clm a plat : plus aucun module a la racine"
  Assert-Equal "" ((Get-TreeMismatch $bin $frBin) -join ",") "installation sur un clm a plat : tout le nouvel arbre est en place"
  Assert-Equal "True|True|True|True|True" ((@("claude-menu.ps1", "claude-menu.cmd", "clm.cmd", "claude-statusline-seed.ps1", "claude-drive-watcher.ps1") | ForEach-Object { [IO.File]::Exists([IO.Path]::Combine($frBin, $_)) }) -join "|") "installation sur un clm a plat : les points d'entree restent a la racine"

  $frOldClm.Commands.Clear()
  $frOldClm.Streams.Error.Clear()
  [void]$frOldClm.AddScript(@'
$group = Import-ClmGroup @("web")
$loader = Start-UsageLoader @("a") $script:FlatUsage "Get-Date"
$until = [DateTime]::UtcNow.AddSeconds(30)
while (-not $loader.Ctl.Done -and [DateTime]::UtcNow -lt $until) { Start-Sleep -Milliseconds 20 }
$halfLoaded = @(Get-ChildItem function: | Where-Object { $_.ScriptBlock.File -and [IO.Path]::GetDirectoryName($_.ScriptBlock.File) -ne $script:ClmModuleDir }).Count
@([string]$group, [string]$script:ClmRestartDue, [string](Test-Path Function:\Start-WebServer), [string]$halfLoaded, [string]($null -ne $loader.Ctl.Error -or $loader.Ctl.Replaced), [string](@($loader.Queue).Count)) -join "|"
'@)
  $frOldSeen = (@($frOldClm.Invoke()) -join "") + (@($frOldClm.Streams.Error | ForEach-Object { " " + $_.ToString() }) -join "")
  Assert-Equal "False|True|False|0|True|0" $frOldSeen "ancien clm a plat pendant la mise a jour : refuse de charger le nouvel arbre et demande un redemarrage"
} finally { $frOldClm.Dispose() }

$frProbe = @'
. ([IO.Path]::Combine($args[0], "claude-import.ps1"))
$script:ClmOnce = New-Object "System.Collections.Generic.HashSet[string]"
. Import-ClmModule claude-ui-loader, claude-lazy-load, claude-usage
$group = Import-ClmGroup @("web", "drive", "sync", "mcp")
$flat = @(Get-ChildItem function: | Where-Object { $_.ScriptBlock.File -and [IO.Path]::GetDirectoryName($_.ScriptBlock.File) -eq $script:ClmModuleDir -and [IO.Path]::GetFileName($_.ScriptBlock.File) -ne "claude-import.ps1" } | ForEach-Object { $_.Name })
@([string]$group, [string](Test-Path Function:\Start-WebServer), [string](Test-Path Function:\Invoke-DriveSync), ($flat -join ",")) -join "|"
'@
$frNewClm = [PowerShell]::Create()
try {
  [void]$frNewClm.AddScript($frProbe).AddArgument($frBin)
  $frNewSeen = (@($frNewClm.Invoke()) -join "") + (@($frNewClm.Streams.Error | ForEach-Object { " " + $_.ToString() }) -join "")
} finally { $frNewClm.Dispose() }
Assert-Equal "True|True|True|" $frNewSeen "clm redemarre apres la mise a jour : tout vient du nouvel arbre, rien de l'ancien a plat"

$frEnv = @{ USERPROFILE = $frRoot; HOME = $frRoot; LOCALAPPDATA = (Join-Path $frRoot "AppData/Local"); APPDATA = (Join-Path $frRoot "AppData/Roaming"); CLAUDE_CONFIG_DIR = $null; CLAUDECODE = $null; CLAUDE_CODE_ENTRYPOINT = $null }
$frRun = Wait-RaceChild (Start-RaceChild ((Join-Path $frBin "claude-menu.ps1") + '" "--help') @{} $frEnv) 60000
Assert-Equal "0|" ([string]$frRun.Code + "|" + $frRun.Err) "clm redemarre apres la mise a jour : le menu demarre sans erreur"
Assert-True ($frRun.Out.Contains("--list")) "clm redemarre apres la mise a jour : aide affichee"
$frWatcher = [PowerShell]::Create()
try {
  [void]$frWatcher.AddScript('param($Bin) . ([IO.Path]::Combine($Bin, "claude-import.ps1")); function Read-ClmStamp { throw "watcher reached" }; try { . ([IO.Path]::Combine($Bin, "claude-drive-watcher.ps1")) } catch { $_.Exception.Message }').AddArgument($frBin)
  $frWatcherSeen = (@($frWatcher.Invoke()) -join "") + (@($frWatcher.Streams.Error | ForEach-Object { " " + $_.ToString() }) -join "")
} finally { $frWatcher.Dispose() }
Assert-Equal "watcher reached" $frWatcherSeen "ancien observateur Drive relance par son chemin a plat : la racine mene au nouveau script"
