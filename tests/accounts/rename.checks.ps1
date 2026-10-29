. (Join-Path $bin "claude-menu-rename.ps1")

$savedFiles = @{}
foreach ($p in @($script:RegistryPath, $script:UsageCachePath)) { if (Test-Path -LiteralPath $p) { $savedFiles[$p] = [IO.File]::ReadAllBytes($p) } }

Save-Registry @(
  [PSCustomObject]@{ Label = "compte1"; Dir = ".claude" },
  [PSCustomObject]@{ Label = "Pro"; Dir = ".claude-compte2" },
  [PSCustomObject]@{ Label = "perso"; Dir = ".claude-compte3" }
)
Save-UsageEntry "Pro" ([PSCustomObject]@{ Pct5 = 12; Reset5 = $null; Pct7 = 34; Reset7 = $null })
$pro = (Get-Accounts)[1]

Assert-Equal (Get-ClmText "accounts.rename.done" @("Pro", "travail")) (Rename-Account $pro "  travail ") "compte renomme, espaces retires"
$accs = @(Get-Accounts)
Assert-Equal "compte1|travail|perso" (($accs | ForEach-Object { $_.Label }) -join "|") "nom change dans le registre, ordre garde"
Assert-Equal ".claude-compte2" $accs[1].Dir "dossier inchange"
$map = Read-UsageCache
Assert-Equal 12 $map["travail"].Pct5 "quotas en cache suivent le nouveau nom"
Assert-True (-not $map.ContainsKey("Pro")) "ancien nom retire du cache"

Assert-Equal (Get-ClmText "accounts.rename.done" @("travail", "Travail")) (Rename-Account $accs[1] "Travail") "changement de casse seul accepte"
Assert-Equal 12 (Read-UsageCache)["Travail"].Pct5 "cache garde au changement de casse"
$accs = @(Get-Accounts)
Assert-Equal (Get-ClmText "accounts.rename.unchanged") (Rename-Account $accs[1] "Travail") "meme nom, rien a faire"

$err = $null
try { $null = Rename-Account $accs[1] "PERSO" } catch { $err = $_.Exception.Message }
Assert-Equal (Get-ClmText "accounts.rename.taken" @("PERSO")) $err "nom d'un autre compte refuse, casse ignoree"
$err = $null
try { $null = Rename-Account $accs[1] "   " } catch { $err = $_.Exception.Message }
Assert-Equal (Get-ClmText "accounts.rename.empty") $err "nom vide refuse"
$err = $null
try { $null = Rename-Account $accs[1] "a,b" } catch { $err = $_.Exception.Message }
Assert-Equal (Get-ClmText "accounts.rename.comma") $err "virgule refusee"
Assert-Equal "compte1|Travail|perso" ((@(Get-Accounts) | ForEach-Object { $_.Label }) -join "|") "refus sans effet sur le registre"

Assert-Equal "rename" (Get-MenuAction (New-KeyInfo "n") 3).Name "n renomme"
Assert-Equal "refresh" (Get-MenuAction (New-KeyInfo "m") 3).Name "m relit le compte"
foreach ($p in @($script:RegistryPath, $script:UsageCachePath)) {
  if ($savedFiles.ContainsKey($p)) { [IO.File]::WriteAllBytes($p, $savedFiles[$p]) } else { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue }
}
