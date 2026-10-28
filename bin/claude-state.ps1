if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-platform.ps1")) { . (Join-Path $PSScriptRoot "claude-platform.ps1") }
$script:StateDirName = "clm"
$script:StateRenames = [ordered]@{
  ".claude-accounts.json" = "accounts.json"
  ".claude-sync-state.json" = "sync-state.json"
  ".claude-sync.lock" = "sync.lock"
  ".clm-drive.json" = "drive.json"
  ".clm-drive-creds.lock" = "drive-creds.lock"
  ".clm-drive-folders.lock" = "drive-folders.lock"
  ".clm-drive-remote.json" = "drive-remote.json"
  ".clm-drive-state.json" = "drive-state.json"
  ".clm-drive.lock" = "drive.lock"
  ".clm-drive-watch" = "drive-watch"
  ".clm-drive-watch.lock" = "drive-watch.lock"
  ".clm-sync-catalog.json" = "sync-catalog.json"
  ".clm-sync-choice.json" = "sync-choice.json"
  ".clm-sync-choice.lock" = "sync-choice.lock"
  ".clm-display.json" = "display.json"
}

function Get-StateDir {
  param([string]$Os = $script:OsName, $Vars = $null)
  if ($Os -eq "Windows") { $dir = Join-OsPath $Os @((Get-LocalAppData $Vars), $script:StateDirName) }
  elseif ($Os -eq "MacOS") { $dir = Join-OsPath $Os @((Get-HomeDir $Vars), "Library", "Application Support", $script:StateDirName) }
  else { $dir = Join-OsPath $Os @((Get-XdgDir "XDG_STATE_HOME" @(".local", "state") $Vars), $script:StateDirName) }
  if ($Os -eq $script:OsName) { try { $null = [IO.Directory]::CreateDirectory($dir) } catch { Write-Verbose $_.Exception.Message } }
  return $dir
}

function Get-OldStateName {
  param([string]$Name)
  foreach ($old in $script:StateRenames.Keys) { if ($script:StateRenames[$old] -ceq $Name) { return $old } }
  return $null
}

function Get-StatePath {
  param([string]$Name, $Vars = $null)
  $path = Join-Path (Get-StateDir -Vars $Vars) $Name
  $old = Get-OldStateName $Name
  if ($null -eq $old -or (Test-Path -LiteralPath $path)) { return $path }
  $legacy = Join-Path (Get-HomeDir $Vars) $old
  if (Test-Path -LiteralPath $legacy) { return $legacy }
  return $path
}
