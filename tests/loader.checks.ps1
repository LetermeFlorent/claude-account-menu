$fake = New-SandboxFile "loader/fake-usage.ps1" @'
function Get-FakeUsage {
  param($Acc)
  if ($Acc.Ms) { Start-Sleep -Milliseconds $Acc.Ms }
  if ($Acc.Fail) { throw ("panne " + $Acc.Name) }
  return "ok " + $Acc.Name
}
'@

function Wait-LoaderDone {
  param($Loader)
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while (-not $Loader.Ctl.Done -and $sw.ElapsedMilliseconds -lt 15000) { Start-Sleep -Milliseconds 20 }
}

$accs = @(@{ Name = "a" }, @{ Name = "b"; Fail = $true }, @{ Name = "c" })
$ld = Start-UsageLoader $accs $fake "Get-FakeUsage"
Wait-LoaderDone $ld
$res = Receive-UsageResults $ld
Close-UsageLoader $ld
Assert-Equal 3 $res.Count "trois resultats"
Assert-Equal "0 ok a" ("" + $res[0][0] + " " + $res[0][1]) "premier compte lu"
Assert-Equal "1 panne b" ("" + $res[1][0] + " " + $res[1][2]) "erreur du deuxieme compte"
Assert-Equal "ok c" $res[2][1] "le suivant est lu malgre l'erreur"
Assert-True $ld.Ctl.Done "chargeur termine"
Assert-Null $ld.Ps "chargeur libere"

$accs = @(@{ Name = "a"; Ms = 400 }, @{ Name = "b" }, @{ Name = "c" })
$ld = Start-UsageLoader $accs $fake "Get-FakeUsage"
$sw = [Diagnostics.Stopwatch]::StartNew()
while ($ld.Ctl.Current -ne 0 -and $sw.ElapsedMilliseconds -lt 15000) { Start-Sleep -Milliseconds 5 }
$waits = 0
Stop-UsageLoader $ld 15000 { $script:waits++ }
$res = Receive-UsageResults $ld
Assert-Equal 1 $res.Count "arret apres le compte en cours"
Assert-Equal "ok a" $res[0][1] "le compte en cours finit sa lecture"
Assert-True ($waits -gt 0) "attente rendue pendant l'arret"

$ld = Start-UsageLoader @(@{ Name = "a" }) (Join-Path $script:Sandbox "absent.ps1") "Get-FakeUsage"
Wait-LoaderDone $ld
$res = Receive-UsageResults $ld
Close-UsageLoader $ld
Assert-True ($ld.Ctl.Error -ne $null) "source absente signalee"
Assert-Equal 0 $res.Count "source absente, aucun resultat"
