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

$ld = Start-UsageLoader @(@{ Name = "a" }) $fake "Get-FakeUsage" -Hold
Start-Sleep -Milliseconds 300
Assert-True ((Test-UsageLoaderHeld $ld) -and -not $ld.Ctl.Done -and $ld.Queue.Count -eq 0) "chargeur retenu : rien lu avant le feu vert"
Resume-UsageLoader $ld
Wait-LoaderDone $ld
Assert-Equal "ok a" (Receive-UsageResults $ld)[0][1] "chargeur retenu : lecture apres le feu vert"
Close-UsageLoader $ld
$ld = Start-UsageLoader @(@{ Name = "a" }) $fake "Get-FakeUsage" -Hold
Stop-UsageLoader $ld 15000
Assert-True ($ld.Ctl.Done -and (Receive-UsageResults $ld).Count -eq 0) "chargeur retenu puis arrete : rien lu, tache finie"

$ld = Start-UsageLoader @(@{ Name = "a" }) (Join-Path $script:Sandbox "absent.ps1") "Get-FakeUsage"
Wait-LoaderDone $ld
$res = Receive-UsageResults $ld
Close-UsageLoader $ld
Assert-True ($null -ne $ld.Ctl.Error) "source absente signalee"
Assert-Equal 0 $res.Count "source absente, aucun resultat"
$rs = Get-UsageRunspace
$ld = Start-UsageLoader @(@{ Name = "a" }) $fake "Get-FakeUsage" -Runspace $rs
Wait-LoaderDone $ld
Close-UsageLoader $ld
$ld = Start-UsageLoader @(@{ Name = "b" }) $fake "Get-FakeUsage" -Runspace (Get-UsageRunspace)
Wait-LoaderDone $ld
Assert-Equal "ok b" (Receive-UsageResults $ld)[0][1] "deuxieme lot lu dans le meme runspace"
Close-UsageLoader $ld
Assert-True ([object]::ReferenceEquals($rs, (Get-UsageRunspace))) "un seul runspace pour toutes les lectures"
Assert-Equal "Opened" ("" + $rs.RunspaceStateInfo.State) "runspace garde ouvert entre deux lots"
