. (Join-Path $PSScriptRoot "claude-usage.ps1")
. (Join-Path $PSScriptRoot "claude-menu-view.ps1")
. (Join-Path $PSScriptRoot "claude-menu-save.ps1")
. (Join-Path $PSScriptRoot "claude-menu-restore.ps1")
. (Join-Path $PSScriptRoot "claude-menu-select.ps1")
. (Join-Path $PSScriptRoot "claude-menu-remove.ps1")
. (Join-Path $PSScriptRoot "claude-statusline-seed.ps1")
. (Join-Path $PSScriptRoot "claude-update.ps1")

function Start-Account {
  param($Acc, $Extra)
  try { Update-StatusState $Acc } catch {}
  Invoke-AsAccount $Acc $Extra
}

$direct = $null
$only = $null
$restoreZip = $null
$update = $true
$rest = @()
foreach ($a in $args) {
  if ($a -match "^-([1-9])$") { $direct = [int]$Matches[1] - 1 }
  elseif ($a -eq "--no-update") { $update = $false }
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

if ($restoreZip) {
  try { $sel = Select-ByLabel @(Get-ZipAccounts $restoreZip) $only } catch { Write-Output $_.Exception.Message; exit 1 }
  Write-Output (Restore-Accounts $restoreZip $sel)
  exit 0
}

if ($direct -ne $null) {
  $accs = @(Get-Accounts)
  if ($direct -ge $accs.Count) { Write-Output ("pas de compte " + ($direct + 1)); exit 1 }
  if ($update) { $null = Update-ClaudeForAccounts $accs }
  Start-Account $accs[$direct] $rest
  exit $LASTEXITCODE
}

function Get-DefaultIndex {
  param($Usages)
  for ($i = 0; $i -lt $Usages.Count; $i++) {
    $u = $Usages[$i]
    if ($u.Error -eq $null -and [int]$u.Pct5 -lt 100 -and [int]$u.Pct7 -lt 100) { return $i }
  }
  return 0
}

$msg = @("", $script:Ink.Dim)
if ($update) { $msg = Update-ClaudeForAccounts @(Get-Accounts) }
Write-Host "Chargement usage..." -ForegroundColor DarkGray
$usages = @(Get-AllUsages)
$idx = Get-DefaultIndex $usages
$chosen = $null
$cursor = $true
try {
  Clear-Host
  $top = [Console]::CursorTop
  try { $cursor = [Console]::CursorVisible } catch {}
  [Console]::CursorVisible = $false
  while ($true) {
    Show-AccountMenu $usages $idx $top
    Write-Segs @(, @($msg[0], $msg[1], $true))
    $k = [Console]::ReadKey($true)
    $redraw = $false
    if ($k.Key -eq "UpArrow") { $idx = ($idx + $usages.Count - 1) % $usages.Count }
    elseif ($k.Key -eq "DownArrow") { $idx = ($idx + 1) % $usages.Count }
    elseif ($k.Key -eq "Enter") { $chosen = $idx; break }
    elseif ($k.KeyChar -match "[1-9]" -and ([int]$k.KeyChar.ToString()) -le $usages.Count) { $chosen = [int]$k.KeyChar.ToString() - 1; break }
    elseif ($k.KeyChar -eq "s") {
      [Console]::CursorVisible = $true
      try { $msg = @(("  " + (Show-SaveMenu)), $script:Levels["7d"][0]) }
      catch { $msg = @(("  sauvegarde impossible : " + $_.Exception.Message), $script:Ink.Alert) }
      $redraw = $true
    }
    elseif ($k.KeyChar -eq "r") {
      [Console]::CursorVisible = $true
      try { $msg = @(("  " + (Show-RestoreMenu)), $script:Levels["7d"][0]) }
      catch { $msg = @(("  restauration impossible : " + $_.Exception.Message), $script:Ink.Alert) }
      $redraw = $true
    }
    elseif ($k.KeyChar -eq "a") {
      [Console]::CursorVisible = $true
      try { $msg = @(("  " + (Add-Account)), $script:Levels["7d"][0]) }
      catch { $msg = @(("  ajout impossible : " + $_.Exception.Message), $script:Ink.Alert) }
      $redraw = $true
    }
    elseif ($k.KeyChar -eq "x") {
      [Console]::CursorVisible = $true
      try { $msg = @(("  " + (Show-RemoveMenu $idx)), $script:Levels["7d"][0]) }
      catch { $msg = @(("  retrait impossible : " + $_.Exception.Message), $script:Ink.Alert) }
      $redraw = $true
    }
    elseif ($k.Key -eq "Escape" -or $k.KeyChar -eq "q") { break }
    if ($redraw) {
      Clear-Host
      Write-Host "Chargement usage..." -ForegroundColor DarkGray
      $usages = @(Get-AllUsages)
      $idx = [math]::Min($idx, $usages.Count - 1)
      Clear-Host
      $top = [Console]::CursorTop
      [Console]::CursorVisible = $false
    }
  }
} catch {
  foreach ($u in $usages) { Write-Host (Format-Row $u) }
  $n = Read-Host ("Numero du compte (1-" + $usages.Count + ")")
  if ($n -match "^[1-9]$" -and [int]$n -le $usages.Count) { $chosen = [int]$n - 1 }
} finally {
  try { [Console]::CursorVisible = $cursor } catch {}
}

if ($chosen -eq $null) { exit 0 }
Clear-Host
Start-Account $usages[$chosen].Acc $rest
exit $LASTEXITCODE
