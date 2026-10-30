if (-not (Test-Path Function:\Import-ClmModule)) { . (Join-Path $PSScriptRoot "../../claude-import.ps1") }
. Import-ClmModule claude-drive-job, claude-text
$script:DriveCliRuns = @{ login = { Invoke-DriveSetup }; key = { Set-SyncPassphrase }; "key-reset" = { Reset-SyncPassphrase }; "key-forget" = { Clear-SyncPassphrase } }
$script:DriveCliFlags = @{ "--drive-login" = "login"; "--sync-key" = "key"; "--sync-key-reset" = "key-reset"; "--sync-key-forget" = "key-forget" }

function Get-DriveCliAction {
  param([object[]]$ArgList)
  foreach ($a in $ArgList) {
    if ($script:DriveCliFlags.ContainsKey([string]$a)) { return @{ Name = $script:DriveCliFlags[[string]$a] } }
    if ($a -eq "--sync") { return @{ Name = "sync"; Force = (@($ArgList) -contains "--force") } }
    if ($a -match "^--sync-auto=(on|off)$") { return @{ Name = "auto"; On = ($Matches[1] -eq "on") } }
    if ($a -match "^--sync-auto") { return @{ Name = "error"; Msg = (Get-ClmText "drive.cli.auto.expects") } }
  }
  return $null
}

function Invoke-DriveCliSync {
  param([bool]$Force)
  if (-not (Test-DriveConnected)) { Write-Host (Get-ClmText "drive.off"); return 1 }
  $r = Invoke-DriveSync ([hashtable]::Synchronized(@{ Stop = $false; Progress = ""; Echo = $true })) 0 -Force:$Force
  Write-Host (Get-DriveSyncMsg $r)
  if ($r.Error) { return 1 }
  return 0
}

function Invoke-DriveCli {
  param($Action)
  if ($Action.Name -eq "error") { Write-Host $Action.Msg; return 1 }
  if ($Action.Name -eq "sync") { return Invoke-DriveCliSync $Action.Force }
  if ($Action.Name -eq "auto") {
    Set-DriveAuto $Action.On
    if ($Action.On) { Write-Host (Get-ClmText "drive.cli.auto.on") } else { Write-Host (Get-ClmText "drive.cli.auto.off") }
    return 0
  }
  try { Write-Host (& $script:DriveCliRuns[$Action.Name]) }
  catch {
    if (Test-LeftToOtherClm $_) { Write-Host (Get-ClmText "drive.passphrase.busy") } else { Write-Host $_.Exception.Message }
    return 1
  }
  return 0
}

function Open-DriveSession {
  param($Acc)
  if (-not (Test-DriveConnected)) { return "" }
  try { $path = Register-DriveSession $Acc } catch { return "" }
  $null = Start-DriveWatcher
  return $path
}

function Submit-DriveSession {
  param([string]$Session)
  $ended = ""
  try { $ended = Close-DriveSession $Session } catch { Write-Verbose $_.Exception.Message }
  if (-not $ended) { return $false }
  if (Wait-DriveWatcher $ended) { return $true }
  try { [IO.File]::Delete($ended) } catch { Write-Verbose $_.Exception.Message }
  return $false
}

function Stop-DriveSession {
  param($Acc, [string]$Session = "")
  $code = $global:LASTEXITCODE
  if (Submit-DriveSession $Session) { Stop-DriveJob $script:DriveJob $script:DriveQuitWaitMs }
  else {
    $end = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() + $script:DriveExitBudgetMs
    Stop-DriveJob $script:DriveJob $script:DriveExitBudgetMs
    Sync-DriveAfterExit $Acc $end
  }
  $global:LASTEXITCODE = $code
}
