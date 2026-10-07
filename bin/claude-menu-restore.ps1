function Show-RestoreMenu {
  $list = @(Get-Backups | Select-Object -First 9)
  Clear-Host
  Write-Host ""
  Write-Host "  Restaurer une sauvegarde"
  Write-Host ("  " + (Get-DownloadsDir)) -ForegroundColor DarkGray
  Write-Host ""
  if ($list.Count -eq 0) {
    Write-Host "  Aucune sauvegarde claude-comptes-*.zip trouvee. Touche quelconque pour revenir." -ForegroundColor DarkGray
    [void][Console]::ReadKey($true)
    return "aucune sauvegarde a restaurer"
  }
  for ($i = 0; $i -lt $list.Count; $i++) {
    $f = $list[$i]
    $mb = [math]::Round($f.Length / 1MB)
    Write-Host ("  " + ($i + 1) + "  " + $f.LastWriteTime.ToString("dd/MM/yyyy HH:mm") + "  " + ("" + $mb + " Mo").PadLeft(7) + "  " + $f.Name)
  }
  Write-Host ""
  Write-Host "  Numero de la sauvegarde, ou Echap pour revenir" -ForegroundColor DarkGray
  $k = [Console]::ReadKey($true)
  if ($k.KeyChar -notmatch "[1-9]") { return "restauration annulee" }
  $n = [int]$k.KeyChar.ToString() - 1
  if ($n -ge $list.Count) { return "restauration annulee" }
  $zip = $list[$n].FullName
  $inZip = @(Get-ZipAccounts $zip)
  if ($inZip.Count -eq 0) { return "aucun compte dans " + $list[$n].Name }
  $picked = Select-Items ("Comptes a restaurer depuis " + $list[$n].Name) @($inZip | ForEach-Object { $_.Label.PadRight(12) + " " + $_.Dir })
  if ($picked -eq $null) { return "restauration annulee" }
  $accs = @($picked | ForEach-Object { $inZip[$_] })
  Write-Host ""
  Write-Host ("  Restaurer " + (@($accs | ForEach-Object { $_.Label }) -join ", ") + " ?")
  Write-Host "  Les fichiers de ces comptes seront remplaces par ceux de la sauvegarde." -ForegroundColor DarkGray
  Write-Host "  Leur etat actuel est d'abord sauvegarde dans Telechargements." -ForegroundColor DarkGray
  Write-Host "  Ferme les autres sessions Claude Code avant, sinon leurs fichiers ouverts seront ignores." -ForegroundColor DarkGray
  Write-Host "  o pour confirmer, autre touche pour annuler" -ForegroundColor DarkGray
  $c = [Console]::ReadKey($true)
  if ($c.KeyChar -ne "o") { return "restauration annulee" }
  Write-Host ""
  Write-Host "  Restauration en cours..." -ForegroundColor DarkGray
  return Restore-Accounts $zip $accs
}
