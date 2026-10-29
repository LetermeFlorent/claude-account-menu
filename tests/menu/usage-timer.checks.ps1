function New-TimerCard {
  param([string]$Label, $P5, $P7, $Err = $null, [bool]$Pending = $false)
  $u = [PSCustomObject]@{ Label = $Label; Email = ($Label + "@exemple.fr"); Plan = ""; Error = $Err; Age = $null; At = $null; Expired = $false; LimitedUntil = $null; Pct5 = $P5; Reset5 = $null; Pct7 = $P7; Reset7 = $null }
  $e = @{ Acc = [PSCustomObject]@{ Label = $Label; Dir = (".claude-timer-" + $Label) }; U = $u; Pending = $Pending; Seen = (-not $Pending); In = $null; View = $null; NextAt = $null; Slot = 0; Force = $false }
  $e.T5 = New-Tween ([double]$P5) ([double]$P5) 0 0
  $e.T7 = New-Tween ([double]$P7) ([double]$P7) 0 0
  Update-EntryView $e
  return $e
}

$e = New-TimerCard "a" 10 10
$e.NextAt = 31000
Assert-Equal "maj 30s" (Get-EntryTimer $e $false 1000 5000)[0] "compteur au depart"
Assert-Equal "maj 8s" (Get-EntryTimer $e $false 23500 5000)[0] "compteur arrondi a la seconde du dessus"
Assert-Equal "maj 0s" (Get-EntryTimer $e $false 40000 5000)[0] "compteur jamais negatif"
$e.NextAt = 186000
Assert-Equal "maj 3m05s" (Get-EntryTimer $e $false 1000 5000)[0] "compteur en minutes"
$e.U.LimitedUntil = 5250
Assert-Equal "pause API 3m05s" (Get-EntryTimer $e $false 1000 5000)[0] "pause de l'API"
Assert-Equal ($script:Levels["7d"][1] -join " ") ((Get-EntryTimer $e $false 1000 5000)[1] -join " ") "pause en orange"
Assert-Equal "maj 3m05s" (Get-EntryTimer $e $false 1000 5300)[0] "pause finie"
$e.U.Error = "panne"
Assert-Equal "reessai 3m05s" (Get-EntryTimer $e $false 1000 5000)[0] "echec avant la pause"
Assert-Equal ($script:Ink.Alert -join " ") ((Get-EntryTimer $e $false 1000 5000)[1] -join " ") "echec en rouge"
$e.Pending = $true
Assert-Equal "lecture..." (Get-EntryTimer $e $false 1000 5000)[0] "relecture en cours"
$e.Seen = $false
Assert-Equal "" (Get-EntryTimer $e $false 1000 5000)[0] "premiere lecture, pas de compteur"
Assert-Equal "en pause" (Get-EntryTimer $e $true 1000 5000)[0] "relecture suspendue pendant une action"


$e = New-TimerCard "a" 10 10
$at = Get-NextReadAt $e 1000 5000 -PollSec 40
Assert-True ($at -ge 41000 -and $at -le 45000) "sans valeur connue, relecture au delai choisi plus un petit alea"
$e.Slot = 60000
Assert-Equal 101000 (Get-NextReadAt $e 1000 5000 -Jitter 0 -PollSec 40) "compte decale au premier tour"
Assert-Equal 0 $e.Slot "decalage pris une seule fois"
$e.U.Age = 10
Assert-Equal 31000 (Get-NextReadAt $e 1000 5000 -Jitter 0 -PollSec 40) "valeur connue, relecture quand elle depasse le delai"
$e.U.Age = 100
Assert-Equal 6000 (Get-NextReadAt $e 1000 5000 -Jitter 0 -PollSec 40) "valeur plus vieille que le delai, relecture apres un court repit"
$e.U.LimitedUntil = 5250
Assert-Equal 252000 (Get-NextReadAt $e 1000 5000 -PollSec 40) "pause de l'API, relecture a sa fin"
$e.U.LimitedUntil = $null
$e.U.Error = "panne"
Assert-Equal 181000 (Get-NextReadAt $e 1000 5000 -Jitter 0 -PollSec 40) "echec, nouvel essai dans 3 min"
$e.U.Error = $null
$e.U.Age = $null
$timerDisplay = Get-StatePath "display.json"
[IO.File]::WriteAllText($timerDisplay, "{ ""usagePoll"": 45 }", (New-Object Text.UTF8Encoding($false)))
Assert-Equal 46000 (Get-NextReadAt $e 1000 5000 -Jitter 0) "delai pris dans les reglages de ce PC"
Remove-Item -LiteralPath $timerDisplay -Force

$st = @{ Entries = @((New-TimerCard "a" 1 1), (New-TimerCard "b" 1 1), (New-TimerCard "c" 1 1)); Busy = $false }
$st.Entries[0].NextAt = 5000
$st.Entries[2].NextAt = 9000
Assert-Equal "0" ((Get-DueEntries $st 6000) -join ",") "seul le compte arrive a echeance est relu"
Assert-Equal "0,2" ((Get-DueEntries $st 9000) -join ",") "comptes a echeance, compte en lecture ignore"

$st = @{ Entries = @((New-TimerCard "a" 1 1), (New-TimerCard "b" 1 1)); Busy = $false; Clock = $null }
$st.Entries[0].NextAt = 31000
$st.Entries[1].NextAt = 61000
Assert-True (Update-MenuTimers $st 1000 5000) "compteurs dessines au premier passage"
Assert-True (-not (Update-MenuTimers $st 1200 5000)) "meme seconde, rien a redessiner"
Assert-True (Update-MenuTimers $st 2100 5000) "seconde suivante, compteurs redessines"
Assert-Equal "maj 29s|maj 59s" (($st.Entries | ForEach-Object { $_.Timer[0] }) -join "|") "un compteur par compte"

$st = @{ Entries = @((New-TimerCard "a" 1 1), (New-TimerCard "b" 1 1), (New-TimerCard "c" 1 1)); Busy = $false; Moved = $true; Sel = 0; Dirty = $false; LoaderIdx = @(2) }
$q = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
$res = [PSCustomObject]@{ Label = "c"; Email = "c@x.fr"; Plan = ""; Error = $null; Age = $null; Expired = $false; LimitedUntil = $null; Pct5 = 42; Reset5 = $null; Pct7 = 5; Reset7 = $null }
$q.Enqueue(@(0, $res, $null))
$st.Loader = @{ Ps = $null; Ctl = @{ Done = $true; Error = $null }; Queue = $q }
Step-MenuLoader $st 1000
Assert-Equal 42 $st.Entries[2].U.Pct5 "resultat range sur le compte relu"
Assert-Equal 1 $st.Entries[0].U.Pct5 "autres comptes intacts"
Assert-Null $st.Loader "lecture terminee"
Assert-True ($st.Entries[2].NextAt -gt 1000) "compte relu replanifie"
Assert-Null $st.Entries[0].NextAt "compte non relu, planning inchange"

$st = @{ Entries = @((New-TimerCard "a" 1 1), (New-TimerCard "b" 1 1 $null $true), (New-TimerCard "c" 1 1)); Sel = 0; Dirty = $false; Msg = $null }
foreach ($x in $st.Entries) { $x.Acc = [PSCustomObject]@{ Label = $x.U.Label }; $x.NextAt = 90000; $x.Force = $false }
Request-EntryRead $st 1000 5000
Assert-True $st.Entries[0].Force "relecture forcee demandee sur le compte choisi"
Assert-Equal 1000 $st.Entries[0].NextAt "compte force a echeance tout de suite"
Assert-Equal "  a : relecture demandee" $st.Msg[0] "message de relecture"
Assert-Equal "lecture..." (Get-EntryTimer $st.Entries[0] $false 1000 5000)[0] "compte force affiche lecture"
Assert-Equal "0" ((Get-DueEntries $st 1000) -join ",") "compte force relu au prochain passage"
$st.Sel = 1
Request-EntryRead $st 1000 5000
Assert-True (-not $st.Entries[1].Force) "compte deja en lecture, rien de plus"
Assert-Equal "  b : lecture deja en cours" $st.Msg[0] "message lecture en cours"
$st.Sel = 2
$st.Entries[2].U.LimitedUntil = 5125
Request-EntryRead $st 1000 5000
Assert-True (-not $st.Entries[2].Force) "pause API respectee"
Assert-Equal 90000 $st.Entries[2].NextAt "pause API, planning inchange"
Assert-Equal "  c : API en pause, reessai dans 2m05s" $st.Msg[0] "message pause API"

$keptLoader = (Get-Item "function:Start-UsageLoader").ScriptBlock
function Start-UsageLoader { param($Accounts, [string]$Source, [string]$Reader = "Get-AccountUsage", $Runspace) return @{ Reader = $Reader; Count = @($Accounts).Count } }
try {
  Start-MenuLoader $st @(0, 2)
  Assert-Equal "Get-FreshUsage" $st.Loader.Reader "lot avec un compte force, cache de 30 s seulement"
  Assert-Equal 2 $st.Loader.Count "lot complet relu"
  Assert-True $st.Entries[0].Force "demande gardee jusqu'au resultat"
  Start-MenuLoader $st @(2)
  Assert-Equal "Get-AccountUsage" $st.Loader.Reader "lot ordinaire, cache de 3 min"
} finally { Set-Item "function:Start-UsageLoader" $keptLoader }
$st.Moved = $true
$fresh = [PSCustomObject]@{ Label = "a"; Email = "a@x.fr"; Plan = ""; Error = $null; Age = $null; Expired = $false; LimitedUntil = $null; Pct5 = 12; Reset5 = $null; Pct7 = 4; Reset7 = $null }
Set-UsageResult $st @(0, $fresh, $null) 2000
Assert-True (-not $st.Entries[0].Force) "demande consommee au resultat"
Assert-True ($st.Msg[0] -match "^  a : quotas relus a \d\d:\d\d:\d\d \(5h 12 %, 7j 4 %\)$") "resultat de la relecture annonce"
$st.Msg = @("autre", $null)
Set-UsageResult $st @(0, $fresh, $null) 2000
Assert-Equal "autre" $st.Msg[0] "lecture ordinaire, message garde"
$fresh.Age = 12
Assert-Equal "  a : deja a jour, lu il y a 12s (5h 12 %, 7j 4 %)" (Get-ForcedReadMsg $st.Entries[0])[0] "cache de moins de 30 s annonce"
$fresh.LimitedUntil = 5090
Assert-Equal "  a : l'API refuse la relecture, reessai dans 1m30s" (Get-ForcedReadMsg $st.Entries[0] 5000)[0] "refus de l'API annonce"
$fresh.LimitedUntil = $null
$fresh.Error = "jeton expire"
Assert-Equal "  a : relecture impossible, jeton expire" (Get-ForcedReadMsg $st.Entries[0])[0] "erreur de relecture annoncee"

$st = @{ Entries = @((New-TimerCard "a" 1 1), (New-TimerCard "b" 1 1)); Busy = $false; Moved = $true; Sel = 0; Dirty = $false; Msg = $null }
function Start-UsageLoader { param($Accounts, [string]$Source, [string]$Reader = "Get-AccountUsage", $Runspace) return @{ Runspace = $Runspace } }
try { Start-MenuLoader $st } finally { Set-Item "function:Start-UsageLoader" $keptLoader }
Assert-True ($null -ne $st.Loader.Runspace) "lot lance dans le runspace partage"
foreach ($i in 0, 1) { Set-UsageResult $st @($i, [PSCustomObject]@{ Label = "x"; Email = ""; Plan = ""; Error = $null; Age = 5; At = $null; Expired = $false; LimitedUntil = $null; Pct5 = 3; Reset5 = $null; Pct7 = 3; Reset7 = $null }, $null) 1000 }
Assert-Equal $st.Entries[0].NextAt $st.Entries[1].NextAt "un seul alea pour tout le lot"
