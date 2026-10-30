. (Join-Path $PSScriptRoot "integration-sandbox.ps1")
. (Join-Path $PSScriptRoot "integration-report.ps1")

$itStartBox = New-ItestSandbox "startup" $true
$itStartClock = [Diagnostics.Stopwatch]::StartNew()
$itStartKids = @(foreach ($n in 1..3) { Start-ItestChild $itStartBox ("s" + $n) "quit" })
Open-RaceGate $itStartBox.Gate $itStartKids.Count
$itStartRuns = @(foreach ($k in $itStartKids) { Wait-RaceChild $k 60000 })
$itStartMs = $itStartClock.ElapsedMilliseconds
$itStartSha = $script:ItestNew.Split(" ")[0]

Assert-Equal "" ((Get-ItestErrors $itStartRuns) -join " | ") "demarrage simultane : aucun clm en erreur"
Assert-Equal "3" (@($itStartRuns | Where-Object { (Get-ItestLastSha $_) -eq $itStartSha }).Count) "demarrage simultane : chaque menu tourne la nouvelle version"
Assert-Equal "" ((Get-ItestBadJson $itStartBox) -join " | ") "demarrage simultane : chaque json se relit"
Assert-Equal "" ((Get-ItestLeftovers $itStartBox) -join " | ") "demarrage simultane : aucun reste ni verrou tenu"
Assert-Equal "1" (Get-ItestMarks $itStartBox "install").Count "demarrage simultane : une seule installation"
Assert-Equal "1" (Get-ItestMarks $itStartBox "claude-update").Count "demarrage simultane : une seule mise a jour de Claude Code"
Assert-Equal "1" (Get-ItestMarkPids $itStartBox "drive").Count "demarrage simultane : un seul tour d'appels Drive"
Assert-Equal "0" (Get-ItestMarks $itStartBox "claude-session").Count "demarrage simultane : aucun compte lance"
Assert-Equal "0" (@(Get-ChildItem -LiteralPath $itStartBox.Home -Recurse -File -Filter "*.zip").Count) "demarrage simultane : aucune archive de sauvegarde au demarrage"
Assert-True ((Get-ItestMarks $itStartBox "usage").Count -ge 3) "demarrage simultane : l'usage de chaque compte est lu"
Assert-True ($itStartMs -lt 60000) ("demarrage simultane : moins de 60 s (" + $itStartMs + " ms)")
[Console]::Out.WriteLine("integration demarrage : " + $itStartMs + " ms, usage " + (Get-ItestMarks $itStartBox "usage").Count + ", drive " + (Get-ItestMarks $itStartBox "drive").Count + ", github " + (Get-ItestMarks $itStartBox "github").Count)
foreach ($itStartRun in $itStartRuns) { [Console]::Out.WriteLine(((Get-RaceLines $itStartRun "start") + (Get-RaceLines $itStartRun "menu") + (Get-RaceLines $itStartRun "key")) -join " / ") }
