if (-not (Test-Path Function:\Import-ClmModule)) { . (Join-Path $PSScriptRoot "../../claude-import.ps1") }
. Import-ClmModule claude-ui-conin, claude-ui-input-gate
$script:ConInMode = -1

function Enable-UiConIn {
  if ($script:OsName -ne "Windows" -or $script:ConInMode -ge 0 -or -not (Test-RichTerminal)) { return }
  if (-not (Initialize-ConIn)) { return }
  try { $script:ConInMode = [ClmConIn]::Enable() } catch { $script:ConInMode = -1 }
}

function Disable-UiConIn {
  if ($script:ConInMode -lt 0) { return }
  try { [ClmConIn]::Restore($script:ConInMode) } catch { Write-Verbose $_.Exception.Message }
  $script:ConInMode = -1
}

function Read-ConInEvent {
  $ev = [ClmConIn]::Next()
  if ($null -eq $ev) { return $null }
  return ,$ev
}

function Read-UiInput {
  if ($script:ConInMode -lt 0) {
    if ([Console]::KeyAvailable) { return [Console]::ReadKey($true) }
    return $null
  }
  while ($true) {
    $ev = Read-ConInEvent
    if ($null -eq $ev) { return $null }
    if ($ev[0] -eq 4) { Set-UiFocus ($ev[1] -eq 1); continue }
    if ($ev[0] -eq 1) {
      Set-UiFocus $true
      if ([Console]::KeyAvailable) { return [Console]::ReadKey($true) }
      return $null
    }
    if ($ev[0] -eq 3) { return @{ KeyUp = (Get-InputKeyCode $ev[1] $ev[2]) } }
  }
}
