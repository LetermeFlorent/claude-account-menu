. (Join-Path $PSScriptRoot "claude-usage.ps1")
. (Join-Path $PSScriptRoot "claude-menu-view.ps1")
. (Join-Path $PSScriptRoot "claude-menu-save.ps1")
. (Join-Path $PSScriptRoot "claude-menu-restore.ps1")
. (Join-Path $PSScriptRoot "claude-menu-select.ps1")
. (Join-Path $PSScriptRoot "claude-menu-remove.ps1")
. (Join-Path $PSScriptRoot "claude-menu-rename.ps1")
. (Join-Path $PSScriptRoot "claude-statusline-seed.ps1")
. (Join-Path $PSScriptRoot "claude-update.ps1")
. (Join-Path $PSScriptRoot "claude-self-update.ps1")
. (Join-Path $PSScriptRoot "claude-sync.ps1")
. (Join-Path $PSScriptRoot "claude-menu-loop.ps1")

function Start-Account {
  param($Acc, $Extra)
  try { Update-StatusState $Acc } catch {}
  Sync-Accounts
  Invoke-AsAccount $Acc $Extra
}

$direct = $null
$only = $null
$restoreZip = $null
$update = $true
$selfUpdate = $true
$rest = @()
foreach ($a in $args) {
  if ($a -match "^-([1-9])$") { $direct = [int]$Matches[1] - 1 }
  elseif ($a -eq "--no-update") { $update = $false; $selfUpdate = $false }
  elseif ($a -eq "--updated") { $selfUpdate = $false }
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

if ($selfUpdate -and (Update-Clm)) { Restart-Clm $PSCommandPath $args }

if ($restoreZip) {
  try {
    $sel = Select-ByLabel @(Get-ZipAccounts $restoreZip) $only
    Write-Output (Restore-Accounts $restoreZip $sel)
  } catch { Write-Output $_.Exception.Message; exit 1 }
  exit 0
}

if ($null -ne $direct) {
  $accs = @(Get-Accounts)
  if ($direct -ge $accs.Count) { Write-Output ("pas de compte " + ($direct + 1)); exit 1 }
  if ($update) { $null = Update-ClaudeForAccounts $accs }
  Start-Account $accs[$direct] $rest
  exit $LASTEXITCODE
}

$chosen = $null
$fallback = -not (Test-RichTerminal)
if (-not $fallback) {
  try { $chosen = Invoke-AccountMenu $update }
  catch {
    Exit-UiScreen
    $fallback = $true
    Write-Host ("  interface indisponible : " + $_.Exception.Message) -ForegroundColor DarkGray
  }
}
if ($fallback) {
  if ($update -and -not $script:MenuUpdated) { $null = Update-ClaudeForAccounts @(Get-Accounts) }
  $usages = @(Get-AllUsages)
  foreach ($u in $usages) { Write-Host (Format-Row $u) }
  $n = Read-Host ("Numero du compte (1-" + $usages.Count + ")")
  if ($n -match "^[1-9]$" -and [int]$n -le $usages.Count) { $chosen = $usages[[int]$n - 1].Acc }
}

if ($null -eq $chosen) { exit 0 }
Clear-Host
Start-Account $chosen $rest
exit $LASTEXITCODE
