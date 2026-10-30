. (Join-Path $bin "menu/loop/claude-menu-select.ps1")
foreach ($zeroName in @("up", "down", "select", "launch", "pick", "refresh")) {
  Assert-Equal "none" (Limit-MenuAction @{ Name = $zeroName; Index = 0 } 0).Name ("menu sans compte : action " + $zeroName + " ignoree")
  Assert-Equal $zeroName (Limit-MenuAction @{ Name = $zeroName; Index = 0 } 2).Name ("menu avec comptes : action " + $zeroName + " gardee")
}
foreach ($zeroName in @("quit", "add", "drivesync", "none")) {
  Assert-Equal $zeroName (Limit-MenuAction @{ Name = $zeroName } 0).Name ("menu sans compte : action " + $zeroName + " gardee")
}

$zeroState = New-MenuState @() 0
Assert-Equal 0 $zeroState.Entries.Count "menu sans compte : etat vide"
Assert-Equal 0 $zeroState.Sel "menu sans compte : selection a zero"

$zeroLoaderCalls = 0
$zeroReal = @{ u = ${function:Start-UsageLoader}; k = ${function:Read-PageKey} }
function Start-UsageLoader { param($Accs, $Reader) $script:zeroLoaderCalls++; return $null }
function Read-PageKey { param($Render) throw "touche lue" }
$zeroErr = ""
try { Start-MenuLoader $zeroState } catch { $zeroErr = $_.Exception.Message }
Assert-Equal "" $zeroErr "menu sans compte : lecture des quotas sans erreur"
Assert-Equal 0 $zeroLoaderCalls "menu sans compte : aucune lecture lancee"
Request-EntryRead $zeroState 0
Assert-Equal "" $zeroErr "menu sans compte : relecture demandee sans erreur"
$zeroErr = ""
$zeroPick = "x"
try { $zeroPick = Select-OneRow "Titre" @() 0 @("a", "b") } catch { $zeroErr = $_.Exception.Message }
Assert-Equal "" $zeroErr "liste vide : choix d'un compte sans erreur"
Assert-Null $zeroPick "liste vide : choix d'un compte annule"
$zeroPick = "x"
try { $zeroPick = Select-Items "Titre" @() } catch { $zeroErr = $_.Exception.Message }
Assert-Equal "" $zeroErr "liste vide : choix de plusieurs comptes sans erreur"
Assert-Null $zeroPick "liste vide : choix de plusieurs comptes annule"
Set-Item Function:\Start-UsageLoader $zeroReal.u
Set-Item Function:\Read-PageKey $zeroReal.k
