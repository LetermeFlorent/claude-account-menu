function Remove-LinkOrTree {
  param([string]$Path)
  $item = Get-Item -LiteralPath $Path -Force
  if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    # skills, agents, regles : liens vers .claude, on retire le lien sans jamais suivre sa cible
    if ($script:OsName -eq "Windows" -and $item.PSIsContainer) { [IO.Directory]::Delete($item.FullName, $false) }
    else { [IO.File]::Delete($item.FullName) }
    return
  }
  if ($item.PSIsContainer) {
    foreach ($c in @(Get-ChildItem -LiteralPath $item.FullName -Force)) { Remove-LinkOrTree $c.FullName }
    [IO.Directory]::Delete($item.FullName, $false)
    return
  }
  try { [IO.File]::Delete($item.FullName); return } catch [UnauthorizedAccessException] {}
  # Lecture seule : les attributs d'un lien dur sont partages, on ne les touche qu'en dernier recours
  $item.Attributes = [IO.FileAttributes]::Normal
  [IO.File]::Delete($item.FullName)
}

function Test-ErasableDir {
  param([string]$Dir)
  return $Dir -match '^\.claude-[^\\/]+$' -and $Dir -notmatch '^\.claude-\.+$'
}

function Remove-Account {
  param($Acc, [bool]$Erase)
  $list = @(Get-Accounts | Where-Object { $_.Dir -ne $Acc.Dir })
  if ($list.Count -eq 0) { throw "c'est le dernier compte" }
  $dir = Get-AccountPath $Acc
  $zip = $null
  if ($Erase) {
    if (-not (Test-ErasableDir $Acc.Dir)) { throw ("le dossier " + $Acc.Dir + " n'est jamais efface") }
    # L'archive passe avant tout : si elle echoue, rien n'est touche
    if (Test-Path -LiteralPath $dir) { $zip = Save-Accounts "" @($Acc) }
  }
  Save-Registry $list
  $msg = $Acc.Label + " retire du menu"
  if (-not $Erase -or -not (Test-Path -LiteralPath $dir)) { return $msg }
  try {
    if ($script:OsName -eq "MacOS") { Remove-KeychainCredential $dir }
    Remove-LinkOrTree $dir
  } catch {
    return $msg + ", mais effacement incomplet de " + $dir + " : " + $_.Exception.Message
  }
  return $msg + ", dossier efface, archive : " + $zip
}

function Format-RemoveItem {
  param($Acc)
  return ($Acc.Label.PadRight(12) + " " + $Acc.Dir.PadRight(18) + " " + (Get-AccountEmail $Acc)).TrimEnd()
}

function Select-OneAccount {
  param($Accs, [int]$Pos)
  $pos = [math]::Max(0, [math]::Min($Pos, $Accs.Count - 1))
  Clear-Host
  $top = [Console]::CursorTop
  while ($true) {
    [Console]::SetCursorPosition(0, $top)
    Write-Segs @(, @("", $script:Ink.Text, $false))
    Write-Segs @(, @("  Retirer un compte", $script:Ink.Text, $true))
    Write-Segs @(, @("", $script:Ink.Text, $false))
    for ($i = 0; $i -lt $Accs.Count; $i++) {
      $mark = "   "
      if ($i -eq $pos) { $mark = " " + $script:Pointer + " " }
      $ink = $script:Ink.Dim
      if ($i -eq $pos) { $ink = $script:Ink.Text }
      Write-Segs @(@($mark, $script:Levels["5h"][0], $true), @(("" + ($i + 1) + "  " + (Format-RemoveItem $Accs[$i])), $ink, ($i -eq $pos)))
    }
    Write-Segs @(, @("", $script:Ink.Text, $false))
    Write-Segs @(, @("  Entree ou 1-9 choisir   Echap annuler", $script:Ink.Dim, $false))
    $k = [Console]::ReadKey($true)
    if ($k.Key -eq "UpArrow") { $pos = ($pos + $Accs.Count - 1) % $Accs.Count }
    elseif ($k.Key -eq "DownArrow") { $pos = ($pos + 1) % $Accs.Count }
    elseif ($k.Key -eq "Enter") { return $pos }
    elseif ($k.KeyChar -match "[1-9]" -and ([int]$k.KeyChar.ToString()) -le $Accs.Count) { return [int]$k.KeyChar.ToString() - 1 }
    elseif ($k.Key -eq "Escape" -or $k.KeyChar -eq "q") { return $null }
  }
}

function Show-RemoveMenu {
  param([int]$Pos)
  $accs = @(Get-Accounts)
  if ($accs.Count -le 1) { return "retrait impossible : c'est le dernier compte" }
  $p = Select-OneAccount $accs $Pos
  if ($p -eq $null) { return "retrait annule" }
  $acc = $accs[$p]
  $erasable = Test-ErasableDir $acc.Dir
  Clear-Host
  Write-Segs @(, @("", $script:Ink.Text, $false))
  Write-Segs @(, @(("  Retirer " + $acc.Label + " (" + $acc.Dir + ")"), $script:Ink.Text, $true))
  Write-Segs @(, @("", $script:Ink.Text, $false))
  Write-Segs @(, @("  1  le retirer du menu, son dossier reste en place", $script:Ink.Text, $false))
  if ($erasable) {
    Write-Segs @(, @("  2  le retirer et effacer son dossier : connexion, historique, reglages", $script:Ink.Alert, $false))
    Write-Segs @(, @("     une archive de securite est d'abord rangee dans Telechargements", $script:Ink.Dim, $false))
    if ($script:OsName -eq "MacOS") {
      Write-Segs @(, @("     la connexion, gardee dans le trousseau, n'est pas dans l'archive", $script:Ink.Dim, $false))
    }
  } else {
    Write-Segs @(, @(("     le dossier " + $acc.Dir + " n'est jamais efface d'ici"), $script:Ink.Dim, $false))
  }
  Write-Segs @(, @("", $script:Ink.Text, $false))
  Write-Segs @(, @("  Echap annuler", $script:Ink.Dim, $false))
  while ($true) {
    $k = [Console]::ReadKey($true)
    if ($k.Key -eq "Escape" -or $k.KeyChar -eq "q") { return "retrait annule" }
    if ($k.KeyChar -eq "1") { return Remove-Account $acc $false }
    if ($k.KeyChar -eq "2" -and $erasable) {
      Write-Segs @(, @("", $script:Ink.Text, $false))
      Write-Segs @(, @("  Sauvegarde puis effacement...", $script:Ink.Dim, $false))
      return Remove-Account $acc $true
    }
  }
}
