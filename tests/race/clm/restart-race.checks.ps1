$rsLab = Split-Path -Parent $PSScriptRoot
. (Join-Path $rsLab "race-helpers.ps1")
. (Join-Path $PSScriptRoot "race-install.ps1")
. (Join-Path $PSScriptRoot "restart-launch.ps1")

$rsHome = New-RaceHome "restart-race"
New-RaceRelease $rsHome.Root @{ "clm-race-marker.ps1" = '$script:RaceMarker = "v6"' }
$rsChild = Join-Path $PSScriptRoot "restart-child.ps1"
$rsIds = @("m1", "m2", "m3")
$rsKids = @(foreach ($id in $rsIds) { Start-MenuChild $rsChild @("--yes", "--only=x", "--continue") (Get-RaceChildEnv $rsHome $id) })
$rsUpParams = @{ Bin = $rsHome.Bin; Lab = $rsLab; Dir = $rsHome.Root; Id = "u1" }
$rsKids += Start-RaceChild (Join-Path $PSScriptRoot "update-child.ps1") $rsUpParams (Get-RaceChildEnv $rsHome "u1")
Open-RaceGate $rsHome.Root $rsKids.Count
$rsRuns = @(foreach ($k in $rsKids) { Wait-RaceChild $k })
$rsMenus = @($rsRuns[0..2])
$rsOld = $script:RaceOldVersion.Split(" ")[0]
$rsNew = $script:RaceNewVersion.Split(" ")[0]

$rsStarts = @(foreach ($r in $rsMenus) { @(Get-RaceLines $r "start" | ForEach-Object { $_.Split(" ")[2] }) -join "," }) -join "|"
$rsEnds = @(foreach ($r in $rsMenus) { @(Get-RaceLines $r "result" | ForEach-Object { $_.Split(" ")[1..3] -join " " }) -join "," }) -join "|"
$rsArgs = @(foreach ($r in $rsMenus) {
  $words = @(Get-RaceLines $r "result" | ForEach-Object { $_.Split(" ") | Select-Object -Skip 4 })
  $dropped = @($words | Where-Object { $_ -ceq "--yes" -or $_ -like "--only=*" }).Count
  (@(foreach ($w in @("--continue", "--no-update", "--updated")) { @($words | Where-Object { $_ -ceq $w }).Count }) + @($dropped)) -join " "
}) -join "|"
$rsStray = @(foreach ($r in $rsMenus) { Get-RaceLines $r "account"; Get-RaceLines $r "stuck"; Get-RaceLines $r "loop" }) -join "|"

$rsName = "trois clm au menu pendant une mise a jour : "
Assert-Equal "" (Format-RaceFailures $rsRuns) ($rsName + "aucune erreur, aucun blocage")
Assert-Equal 1 @(Get-ChildItem -LiteralPath $rsHome.Root -Filter "install-*").Count ($rsName + "un seul installe")
Assert-Equal (@($rsIds | ForEach-Object { $rsOld + "," + $rsNew }) -join "|") $rsStarts ($rsName + "chacun demarre deux fois, ancienne puis nouvelle version")
Assert-Equal (@($rsIds | ForEach-Object { $_ + " " + $rsNew + " v6" }) -join "|") $rsEnds ($rsName + "tous redemarrent sur la nouvelle version")
Assert-Equal "" $rsStray ($rsName + "aucun compte ouvert, aucun clm reste sur l'ancienne version")
Assert-Equal "1 1 1 0|1 1 1 0|1 1 1 0" $rsArgs ($rsName + "arguments gardes, --yes et --only= retires au redemarrage")
Assert-Equal ("result u1 True " + $rsNew) (Get-RaceResults @($rsRuns[3])) ($rsName + "le clm qui installe repart sur la nouvelle version")
