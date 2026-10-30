if (-not (Test-Path Function:\Import-ClmModule)) { . (Join-Path $PSScriptRoot "../../claude-import.ps1") }
. Import-ClmModule claude-text
function Select-Items {
  param([string]$Title, [string[]]$Items)
  if (@($Items).Count -eq 0) { return $null }
  $on = New-Object bool[] $Items.Count
  for ($i = 0; $i -lt $on.Count; $i++) { $on[$i] = $true }
  $pos = 0
  $pairs = @((Get-ClmText "menu.select.key.space"), (Get-ClmText "menu.select.action.tick"), "t", (Get-ClmText "menu.select.action.all"), (Get-ClmText "menu.select.key.enter"), (Get-ClmText "menu.select.action.confirm"), (Get-ClmText "menu.select.key.escape"), (Get-ClmText "menu.select.action.cancel"))
  while ($true) {
    $k = Read-PageKey { Get-PageRows $Title (Get-ListRows $Items $pos $on) $pairs }
    if ($k.Key -eq "UpArrow") { $pos = ($pos + $Items.Count - 1) % $Items.Count }
    elseif ($k.Key -eq "DownArrow") { $pos = ($pos + 1) % $Items.Count }
    elseif ($k.Key -eq "Spacebar") { $on[$pos] = -not $on[$pos] }
    elseif ($k.KeyChar -eq "t") {
      $all = $true
      foreach ($v in $on) { if (-not $v) { $all = $false } }
      for ($i = 0; $i -lt $on.Count; $i++) { $on[$i] = -not $all }
    }
    elseif ($k.Key -eq "Enter") {
      $picked = @(for ($i = 0; $i -lt $on.Count; $i++) { if ($on[$i]) { $i } })
      if ($picked.Count -gt 0) { return ,$picked }
    }
    elseif ($k.Key -eq "Escape") { return $null }
  }
}

function Format-AccountItem {
  param($Acc)
  $mail = Get-AccountEmail $Acc
  $txt = $Acc.Label.PadRight(12) + " " + $Acc.Dir.PadRight(18)
  if ($mail) { $txt += " " + $mail }
  if ($Acc.Dir -eq ".claude") { $txt += "  " + (Get-ClmText "menu.select.shared") }
  return $txt
}

function Show-SaveMenu {
  $accs = @(Get-Accounts)
  $picked = Select-Items (Get-ClmText "menu.select.save.title") @($accs | ForEach-Object { Format-AccountItem $_ })
  if ($null -eq $picked) { return Get-ClmText "menu.select.save.cancelled" }
  return Invoke-UiWork (Get-ClmText "menu.select.save.work") (Get-ClmText "menu.select.save.running") { Get-ClmText "menu.select.save.done" @(Save-Accounts "" @($picked | ForEach-Object { $accs[$_] })) }
}

function Select-ByLabel {
  param($Accs, [string]$Labels)
  if ([string]::IsNullOrWhiteSpace($Labels)) { return $Accs }
  $want = @($Labels -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  $unknown = @($want | Where-Object { $w = $_; @($Accs | Where-Object { $_.Label -eq $w }).Count -eq 0 })
  if ($unknown.Count -gt 0) { throw (Get-ClmText "menu.select.unknown" @($unknown -join ", ")) }
  return @($Accs | Where-Object { $want -contains $_.Label })
}

function Read-AccountNumber {
  param($Usages)
  $count = 0
  if ($null -ne $Usages) { $count = @($Usages).Count }
  if ($count -eq 0) {
    Write-Host ("  " + (Get-ClmText "menu.select.noAccount"))
    return $null
  }
  Clear-SettledInput
  $n = Read-Host (Get-ClmText "menu.select.number" @($count))
  if ($n -match "^[1-9]$" -and [int]$n -le $count) { return $Usages[[int]$n - 1].Acc }
  return $null
}
