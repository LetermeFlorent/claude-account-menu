function Get-RestoreWarn {
  param($Changes = @())
  $rows = New-Object System.Collections.Generic.List[object]
  $rows.Add((New-TextRow "  Les fichiers de ces comptes seront remplaces par ceux de la sauvegarde." $script:Ink.Dim))
  $rows.Add((New-TextRow "  Leur etat actuel est d'abord sauvegarde dans Telechargements." $script:Ink.Dim))
  $rows.Add((New-TextRow "  Ferme les autres sessions Claude Code avant, sinon leurs fichiers ouverts seront ignores." $script:Ink.Dim))
  $rows.Add((New-TextRow "  Une connexion utilisee ou renouvelee depuis la sauvegarde demandera un /login." $script:Ink.Dim))
  if (@($Changes).Count -eq 0) { return ,$rows }
  $rows.Add((New-TextRow "  Ces reglages lancent des commandes et changeront, verifier qu'ils viennent bien de toi :" $script:Ink.Alert))
  foreach ($c in @($Changes)) { $rows.Add((New-TextRow ("    " + $c) $script:Ink.Alert)) }
  return ,$rows
}

function Show-RestoreMenu {
  $list = @(Get-Backups | Select-Object -First 9)
  $title = "Restaurer une sauvegarde"
  $dir = Get-DownloadsDir
  if ($list.Count -eq 0) {
    $null = Read-PageKey { Get-PageRows $title @(, (New-TextRow "  Aucune sauvegarde claude-comptes-* trouvee. Touche quelconque pour revenir." $script:Ink.Dim)) @() $dir }
    return "aucune sauvegarde a restaurer"
  }
  $items = @(foreach ($f in $list) { $f.LastWriteTime.ToString("dd/MM/yyyy HH:mm") + "  " + ("" + [math]::Round($f.Length / 1MB) + " Mo").PadLeft(7) + "  " + $f.Name })
  $n = Select-OneRow $title $items 0 @("Entree ou 1-9", "choisir", "Echap", "revenir") $dir
  if ($null -eq $n) { return "restauration annulee" }
  $zip = $list[$n].FullName
  Assert-BackupVersion $zip
  $inZip = @(Get-ZipAccounts $zip)
  if ($inZip.Count -eq 0) { return "aucun compte dans " + $list[$n].Name }
  $picked = Select-Items ("Comptes a restaurer depuis " + $list[$n].Name) @($inZip | ForEach-Object { $_.Label.PadRight(12) + " " + $_.Dir })
  if ($null -eq $picked) { return "restauration annulee" }
  $accs = @($picked | ForEach-Object { $inZip[$_] })
  $ask = "Restaurer " + (@($accs | ForEach-Object { $_.Label }) -join ", ") + " ?"
  $changes = @(Get-RestoreChanges $zip $accs)
  $c = Read-PageKey { Get-PageRows $ask (Get-RestoreWarn $changes) @("o", "confirmer", "autre touche", "annuler") }
  if ($c.KeyChar -ne "o") { return "restauration annulee" }
  return Invoke-UiWork $ask "Restauration en cours..." { Restore-Accounts $zip $accs -Yes }
}
