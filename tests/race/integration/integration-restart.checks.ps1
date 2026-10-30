. (Join-Path $PSScriptRoot "integration-sandbox.ps1")
. (Join-Path $PSScriptRoot "integration-report.ps1")

$itRestBox = New-ItestSandbox "restart" $false
$itRestClock = [Diagnostics.Stopwatch]::StartNew()
$itRestKids = [ordered]@{
  r1 = Start-ItestChild $itRestBox "r1" "update"
  r2 = Start-ItestChild $itRestBox "r2" "stay"
  r3 = Start-ItestChild $itRestBox "r3" "stay"
  r4 = Start-ItestChild $itRestBox "r4" "session" @() @{ CLM_ITEST_HOLD = "1" }
}
Open-RaceGate $itRestBox.Gate $itRestKids.Count
$itRestShown = (Wait-ItestMarks $itRestBox "menu-1" 4) -and (Wait-ItestMarks $itRestBox "claude-session" 1)
Get-ChildItem -LiteralPath $itRestBox.State -Filter "claude-check*" | Remove-Item -Force
Set-ItestRelease $itRestBox $true
[IO.File]::WriteAllText((Join-Path $itRestBox.Log "update-now"), "go")
$itRestMoved = Wait-ItestMarks $itRestBox "menu-2" 3
[IO.File]::WriteAllText((Join-Path $itRestBox.Log "quit-all"), "go")
[IO.File]::WriteAllText((Join-Path $itRestBox.Log "session-end"), "go")
$itRestRuns = [ordered]@{}
foreach ($itRestId in $itRestKids.Keys) { $itRestRuns[$itRestId] = Wait-RaceChild $itRestKids[$itRestId] 60000 }
$itRestMs = $itRestClock.ElapsedMilliseconds
$itRestSha = $script:ItestNew.Split(" ")[0]
$itRestMenus = @($itRestRuns["r1"], $itRestRuns["r2"], $itRestRuns["r3"])

Assert-True $itRestShown "relance : trois menus ouverts et un compte en session"
Assert-True $itRestMoved "relance : trois menus rouverts apres l'installation"
Assert-Equal "" ((Get-ItestErrors @($itRestRuns.Values)) -join " | ") "relance : aucun clm en erreur"
Assert-Equal "3" (@($itRestMenus | Where-Object { (Get-ItestLastSha $_) -eq $itRestSha }).Count) "relance : chaque menu relance tourne la nouvelle version"
Assert-Equal "2 2 2" ((@($itRestMenus | ForEach-Object { @(Get-RaceLines $_ "start").Count })) -join " ") "relance : une seule relance par menu, sans boucle"
Assert-Equal "1" (Get-ItestMarks $itRestBox "install").Count "relance : une seule installation"
Assert-Equal "2" (@(Get-RaceLines $itRestRuns["r2"] "menu") + @(Get-RaceLines $itRestRuns["r3"] "menu") | Where-Object { $_ -like "*--no-update*" }).Count "relance : la relance sur place passe --no-update"
Assert-Equal "" ((Get-ItestMarkTexts $itRestBox "claude-update" | Where-Object { -not $_.StartsWith("r") -or $_.Split(" ")[1] -ne "1" }) -join " | ") "relance : aucune mise a jour de Claude Code apres une relance"
Assert-Equal "r4 1" ((Get-ItestMarkTexts $itRestBox "claude-session" | ForEach-Object { $_.Split(" ")[0] + " " + $_.Split(" ")[1] }) -join " | ") "relance : seul le compte deja en session a lance claude"
Assert-Equal "1" @(Get-RaceLines $itRestRuns["r4"] "start").Count "relance : le clm en session n'est pas relance"
Assert-Equal "1" (Get-ItestMarks $itRestBox "claude-ended").Count "relance : la session va jusqu'a sa fin"
Assert-Equal "" ((Get-ItestBadJson $itRestBox) -join " | ") "relance : chaque json se relit"
Assert-Equal "" ((Get-ItestLeftovers $itRestBox) -join " | ") "relance : aucun reste ni verrou tenu"
Assert-True ($itRestMs -lt 60000) ("relance : moins de 60 s (" + $itRestMs + " ms)")
[Console]::Out.WriteLine("integration relance : " + $itRestMs + " ms, claude " + ((Get-ItestMarkTexts $itRestBox "claude-update") -join " ; "))
foreach ($itRestId in $itRestRuns.Keys) { [Console]::Out.WriteLine($itRestId + " " + $itRestRuns[$itRestId].Code + " " + (((Get-RaceLines $itRestRuns[$itRestId] "start") + (Get-RaceLines $itRestRuns[$itRestId] "menu") + (Get-RaceLines $itRestRuns[$itRestId] "key")) -join " / ")) }
