. (Join-Path $bin "claude-menu-select.ps1")

$accs = @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" }, [PSCustomObject]@{ Label = "Pro"; Dir = ".claude-compte2" }, [PSCustomObject]@{ Label = "perso"; Dir = ".claude-compte3" })
Assert-Equal "compte1|Pro|perso" ((@(Select-ByLabel $accs "") | ForEach-Object { $_.Label }) -join "|") "selection vide : tous les comptes"
Assert-Equal "Pro|perso" ((@(Select-ByLabel $accs " perso, pro ") | ForEach-Object { $_.Label }) -join "|") "selection par nom, casse et espaces ignores"
$err = $null
try { $null = Select-ByLabel $accs "pro,prso" } catch { $err = $_.Exception.Message }
Assert-Equal "compte inconnu : prso" $err "nom mal tape refuse"
