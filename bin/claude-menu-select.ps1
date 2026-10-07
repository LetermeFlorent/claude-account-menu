function Select-Items {
  param([string]$Title, [string[]]$Items)
  $on = @($Items | ForEach-Object { $true })
  $pos = 0
  Clear-Host
  $top = [Console]::CursorTop
  while ($true) {
    [Console]::SetCursorPosition(0, $top)
    Write-Host ""
    Write-Host ("  " + $Title).PadRight(78)
    Write-Host ""
    for ($i = 0; $i -lt $Items.Count; $i++) {
      $box = "[ ]"
      if ($on[$i]) { $box = "[x]" }
      $mark = "   "
      if ($i -eq $pos) { $mark = " " + [char]0x276F + " " }
      $color = "DarkGray"
      if ($i -eq $pos) { $color = "Cyan" }
      Write-Host ($mark + $box + " " + $Items[$i]).PadRight(78) -ForegroundColor $color
    }
    Write-Host ""
    Write-Host "  Espace cocher   t tout   Entree valider   Echap annuler".PadRight(78) -ForegroundColor DarkGray
    $k = [Console]::ReadKey($true)
    if ($k.Key -eq "UpArrow") { $pos = ($pos + $Items.Count - 1) % $Items.Count }
    elseif ($k.Key -eq "DownArrow") { $pos = ($pos + 1) % $Items.Count }
    elseif ($k.Key -eq "Spacebar") { $on[$pos] = -not $on[$pos] }
    elseif ($k.KeyChar -eq "t") {
      $all = @($on | Where-Object { $_ }).Count -eq $on.Count
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
  if ($Acc.Dir -eq ".claude") { $txt += "  (+ skills, agents, regles partages)" }
  return $txt
}

function Show-SaveMenu {
  $accs = @(Get-Accounts)
  $picked = Select-Items "Comptes a sauvegarder" @($accs | ForEach-Object { Format-AccountItem $_ })
  if ($picked -eq $null) { return "sauvegarde annulee" }
  Write-Host ""
  Write-Host "  Sauvegarde en cours..." -ForegroundColor DarkGray
  return "sauvegarde : " + (Save-Accounts "" @($picked | ForEach-Object { $accs[$_] }))
}

function Select-ByLabel {
  param($Accs, [string]$Labels)
  if ([string]::IsNullOrWhiteSpace($Labels)) { return $Accs }
  $want = @($Labels -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  # Un nom mal tape ne doit jamais retomber sur tous les comptes
  $unknown = @($want | Where-Object { $w = $_; @($Accs | Where-Object { $_.Label -eq $w }).Count -eq 0 })
  if ($unknown.Count -gt 0) { throw ("compte inconnu : " + ($unknown -join ", ")) }
  return @($Accs | Where-Object { $want -contains $_.Label })
}
