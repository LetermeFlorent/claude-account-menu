if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-state.ps1")) { . (Join-Path $PSScriptRoot "claude-state.ps1") }
$script:StateLockExt = ".lock"
$script:StateTmpExt = ".tmp"
$script:StateTmpMinAgeMinutes = 10

function Test-StateLockHeld {
  param([string]$Path)
  if (-not [IO.File]::Exists($Path)) { return $false }
  try { $fs = [IO.File]::Open($Path, "Open", "ReadWrite", "None") } catch { return $true }
  $fs.Dispose()
  return $false
}

function Test-OldStateBusy {
  param([string]$HomeDir)
  foreach ($old in $script:StateRenames.Keys) {
    if ($old.EndsWith($script:StateLockExt) -and (Test-StateLockHeld (Join-Path $HomeDir $old))) { return $true }
  }
  return $false
}

function Move-StateEntry {
  param([string]$Old, [string]$New)
  if (-not (Test-Path -LiteralPath $Old)) { return }
  try {
    if (Test-Path -LiteralPath $New) { Remove-Item -LiteralPath $Old -Recurse -Force -ErrorAction Stop }
    elseif ([IO.Directory]::Exists($Old)) { [IO.Directory]::Move($Old, $New) }
    else { [IO.File]::Move($Old, $New) }
  } catch {}
}

function Test-StateLeftover {
  param([string]$Name)
  if (-not $Name.EndsWith($script:StateTmpExt)) { return $false }
  foreach ($old in $script:StateRenames.Keys) { if ($Name.StartsWith($old + ".")) { return $true } }
  return $false
}

function Remove-StateLeftovers {
  param([string]$HomeDir)
  $limit = [DateTime]::UtcNow.AddMinutes(-$script:StateTmpMinAgeMinutes)
  try { $files = [IO.Directory]::GetFiles($HomeDir, "*" + $script:StateTmpExt) } catch { return }
  foreach ($f in $files) {
    if (-not (Test-StateLeftover ([IO.Path]::GetFileName($f)))) { continue }
    try { if ([IO.File]::GetLastWriteTimeUtc($f) -lt $limit) { [IO.File]::Delete($f) } } catch {}
  }
}

function Invoke-StateMigration {
  param($Vars = $null)
  $homeDir = Get-HomeDir $Vars
  if (Test-OldStateBusy $homeDir) { return $false }
  $dir = Get-StateDir -Vars $Vars
  foreach ($old in $script:StateRenames.Keys) { Move-StateEntry (Join-Path $homeDir $old) (Join-Path $dir $script:StateRenames[$old]) }
  Remove-StateLeftovers $homeDir
  return $true
}
