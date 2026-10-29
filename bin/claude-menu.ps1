$script:ClmOnce = New-Object 'System.Collections.Generic.HashSet[string]'
if (-not (Test-Path Function:\Import-ClmModule)) { . (Join-Path $PSScriptRoot "claude-import.ps1") }
. Import-ClmModule claude-state-migrate
$null = Invoke-StateMigration
. Import-ClmModule claude-boot-bar
$script:BootBar = Start-BootBar $args $PSScriptRoot $script:ClmOnce
. Import-ClmModule claude-usage, claude-menu-view, claude-menu-save, claude-menu-restore, claude-menu-select,
  claude-menu-remove, claude-menu-rename, claude-menu-prefs, claude-statusline-seed, claude-update, claude-self-update,
  claude-sync, claude-menu-loop, claude-menu-startup, claude-drive-cli, claude-account-guard, claude-cli
Set-BootBarReady

function Start-Account {
  param($Acc, $Extra)
  try { Update-StatusState $Acc } catch { Write-Verbose $_.Exception.Message }
  Sync-Accounts
  Sync-DriveBeforeLaunch $Acc
  Repair-AccountConfig $Acc
  $session = Open-DriveSession $Acc
  try { Invoke-AsAccount $Acc $Extra }
  finally { Stop-DriveSession $Acc $session }
}

function Assert-Online {
  if (Test-Network) { return }
  Stop-BootBar
  Write-Output ("  " + $script:OfflineText)
  exit 1
}

function Invoke-TextStartup {
  param([bool]$Update, [bool]$Drive)
  if ($Update) { Update-ClaudeForAccounts @(Get-Accounts) }
  if ($Drive -and (Test-DriveAuto)) { $null = Invoke-DriveCliSync $false }
  Assert-Online
}

$cli = Get-CliCommand $args
if ($null -ne $cli) {
  $code = Invoke-CliCommand $cli $args
  if ($script:CliRestart) { Restart-Clm $PSCommandPath $args }
  exit $code
}

$direct = $null
$only = $null
$restoreZip = $null
$update = $true
$selfUpdate = $true
$openWeb = $false
$rest = @()
foreach ($a in $args) {
  if ($a -match "^-([1-9])$") { $direct = [int]$Matches[1] - 1 }
  elseif ($a -eq "--no-update") { $update = $false; $selfUpdate = $false }
  elseif ($a -eq "--updated") { $selfUpdate = $false }
  elseif ($a -eq $script:WebFlag) { $openWeb = $true }
  elseif ($a -eq "--usage") {
    foreach ($u in Get-AllUsages) { Write-Output (Format-Row $u) }
    exit 0
  }
  elseif ($a -match "^--save(=(.+))?$") {
    try { $sel = Select-ByLabel @(Get-Accounts) $Matches[2] } catch { Write-Output $_.Exception.Message; exit 1 }
    Write-Output ("sauvegarde : " + (Save-Accounts "" $sel))
    exit 0
  }
  elseif ($a -match "^--only=(.+)$") { $only = $Matches[1] }
  elseif ($a -match "^--restore=(.+)$") { $restoreZip = $Matches[1] }
  else { $rest = $rest + $a }
}

$driveCli = Get-DriveCliAction $args
$menuMode = $null -eq $driveCli -and -not $restoreZip -and $null -eq $direct -and (Test-RichTerminal)
if ($openWeb -and -not $menuMode) {
  Write-Output "  --web ouvre la page avec le menu de clm, dans un terminal interactif"
  exit 1
}
if ($null -eq $driveCli -and -not $restoreZip) { Assert-Online }
if ($selfUpdate -and -not $menuMode -and (Update-Clm)) { Restart-Clm $PSCommandPath $args }
if ($null -ne $driveCli) { exit (Invoke-DriveCli $driveCli) }

if ($restoreZip) {
  try {
    $sel = Select-ByLabel @(Get-ZipAccounts $restoreZip) $only
    Write-Output (Restore-Accounts $restoreZip $sel -AllowForeign -Yes:($args -contains "--yes"))
  } catch { Write-Output $_.Exception.Message; exit 1 }
  exit 0
}

if ($null -ne $direct) {
  $accs = @(Get-Accounts)
  if ($direct -ge $accs.Count) { Write-Output ("pas de compte " + ($direct + 1)); exit 1 }
  Invoke-TextStartup $update $true
  Start-Account $accs[$direct] $rest
  exit $LASTEXITCODE
}

$chosen = $null
$fallback = -not $menuMode
if ($menuMode) {
  try { $chosen = Invoke-AccountMenu $update $selfUpdate $openWeb }
  catch {
    Exit-UiScreen
    $fallback = $true
    Write-Host ("  interface indisponible : " + $_.Exception.Message) -ForegroundColor DarkGray
  }
}
if ($script:MenuOffline) {
  Write-Output ("  " + $script:OfflineText)
  exit 1
}
if ($script:ClmUpdated) {
  Write-Host "  clm mis a jour, redemarrage" -ForegroundColor DarkGray
  Restart-Clm $PSCommandPath (Get-WebRestartArgs $args)
}
if ($fallback) {
  if ($selfUpdate -and $menuMode -and -not $script:ClmChecked -and (Update-Clm)) { Restart-Clm $PSCommandPath $args }
  Invoke-TextStartup ($update -and -not $script:MenuUpdated) (-not $script:DriveChecked)
  $usages = @(Get-AllUsages)
  foreach ($u in $usages) { Write-Host (Format-Row $u) }
  $chosen = Read-AccountNumber $usages
}

if ($script:MenuRestart) {
  Clear-Host
  if (-not (Update-Clm)) { Start-Sleep -Seconds 3 }
  Restart-Clm $PSCommandPath (Get-WebRestartArgs $args)
}

if ($null -eq $chosen) { exit 0 }
Clear-Host
Start-Account $chosen $rest
exit $LASTEXITCODE
