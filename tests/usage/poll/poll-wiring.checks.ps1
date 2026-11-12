$pwSaved = @{ Menu = $script:MenuState; Web = $script:Web; Poll = $script:UiPoll; Open = $script:WebOpen; Reopen = $script:WebReopen; Drive = $script:DriveJob; Startup = $script:Startup; Check = $script:ClmCheck }
. (Join-Path $bin "menu/loop/claude-menu-loop.ps1")
. (Join-Path $bin "usage/claude-usage-poll.ps1")

$pwFaked = @("Get-NowMs", "Start-UsageLoader", "Start-WebServer", "Open-Browser")
$pwKept = @{}
foreach ($n in $pwFaked) { $pwKept[$n] = (Get-Item ("function:" + $n)).ScriptBlock }
$pwBar = Get-StatusStatePath
$pwFiles = @{}
foreach ($p in @($pwBar, (Get-DisplayPath), $script:UsageCachePath)) { $pwFiles[$p] = $null; if ([IO.File]::Exists($p)) { $pwFiles[$p] = [IO.File]::ReadAllBytes($p) } }
$pwUnix = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$pwAccs = @([PSCustomObject]@{ Label = "fil"; Dir = ".claude-fil" }, [PSCustomObject]@{ Label = "fil2"; Dir = ".claude-fil2" })
$pwMaj = [regex]::Escape((Get-ClmText "menu.timer.update" ""))
$script:PwClock = 0.0
$script:PwViews = $null

function Get-NowMs { return $script:PwClock }

function Start-UsageLoader {
  param($Accounts, [string]$Source, [string]$Reader = "Get-AccountUsage", $Runspace)
  $q = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
  $i = 0
  foreach ($a in @($Accounts)) {
    $u = New-UsageRow $a ($a.Label + "@exemple.fr")
    $u.Pct5 = 7; $u.Reset5 = [DateTimeOffset]::UtcNow.AddHours(2).ToString("o")
    $u.Pct7 = 3; $u.Reset7 = [DateTimeOffset]::UtcNow.AddDays(3).ToString("o")
    $u.Age = 0; $u.At = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $q.Enqueue(@($i, $u, $null))
    $i++
  }
  return @{ Ps = $null; Ctl = @{ Done = $true; Error = $null }; Queue = $q }
}

function Start-WebServer { param([hashtable]$Views) $script:PwViews = $Views; return $null }
function Open-Browser { param([string]$Url) return $true }

function Write-PwBar {
  param([int]$Pct5)
  $at = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() + 1
  Save-UsageEntry "fil" ([PSCustomObject]@{ Pct5 = $Pct5; Reset5 = [DateTimeOffset]::FromUnixTimeSeconds($pwUnix + 3600).ToString("o"); Pct7 = 3; Reset7 = [DateTimeOffset]::FromUnixTimeSeconds($pwUnix + 86400).ToString("o") }) $at
}

function Step-PwFrame {
  param([double]$At)
  $script:PwClock = $At
  Step-MenuLoader $script:MenuState (Get-NowMs)
  $null = Update-MenuTimers $script:MenuState (Get-NowMs)
}

function Read-PwWeb {
  $j = ConvertFrom-JsonText (ConvertTo-JsonText (& $script:PwViews["state"]))
  return $j["accounts"][0]["q5"]["pct"]
}

function Read-PwCard {
  param($E, [double]$At)
  return ((Get-CompactUsageSegs @{ Usage = $E.U; Cells = 10; View = $E.View; Tween5 = $E.T5; Tween7 = $E.T7; Now = $At }) | ForEach-Object { $_[0] }) -join ""
}

function Get-PwApiTimer {
  $script:PwClock = 50000.0
  $s = New-MenuState $pwAccs (Get-NowMs) $false
  Start-MenuLoader $s
  Step-MenuLoader $s (Get-NowMs)
  $null = Update-MenuTimers $s (Get-NowMs)
  return @(($s.Entries[0].NextAt - (Get-NowMs)), $null, $s.Entries[0].Timer[0], $s.PollSec)
}

try {
  $script:Web = $null; $script:DriveJob = $null; $script:Startup = $null; $script:ClmCheck = $null
  foreach ($p in @($pwFiles.Keys)) { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue }
  New-Item -ItemType Directory -Force -Path (Split-Path $pwBar) | Out-Null
  $pwPeriod = [double]$script:LiveCheckMs
  Assert-Equal 2000 $pwPeriod "lecture d'un autre clm : fichier relu toutes les 2 s"

  $script:MenuState = New-MenuState @($pwAccs[0]) (Get-NowMs) $false
  Start-MenuLoader $script:MenuState
  Open-MenuWeb $script:MenuState
  $script:WebOpen = $true
  Assert-True ($null -ne $script:PwViews -and $script:PwViews.ContainsKey("state")) "lecture d'un autre clm : vue state branchee par Open-MenuWeb"
  $pe = $script:MenuState.Entries[0]
  Step-PwFrame 0
  Assert-Equal 7 $pe.U.Pct5 "lecture d'un autre clm : carte remplie par l'API simulee"
  Assert-Equal 7 (Read-PwWeb) "lecture d'un autre clm : page web remplie par l'API simulee"

  $script:PwClock = 100.0
  Write-PwBar 63
  foreach ($t in @(1000.0, ($pwPeriod - 1))) {
    Step-PwFrame $t
    Assert-Equal 7 $pe.U.Pct5 ("lecture d'un autre clm : carte inchangee a " + $t + " ms")
    Assert-Equal 7 (Read-PwWeb) ("lecture d'un autre clm : page web inchangee a " + $t + " ms")
  }
  Assert-True ((Read-PwCard $pe ($pwPeriod - 1)).Contains(" 7%")) "lecture d'un autre clm : carte dessinee avec l'ancienne valeur avant 2 s"

  Step-PwFrame $pwPeriod
  Assert-Equal 63 $pe.U.Pct5 "lecture d'un autre clm : valeur fraiche dans la carte a 2 s"
  Assert-Equal 63 $pe.T5.To "lecture d'un autre clm : barre 5h animee vers la valeur fraiche"
  Assert-Equal 63 (Read-PwWeb) "lecture d'un autre clm : valeur fraiche dans la page web a 2 s"
  Assert-True ((Read-PwCard $pe ($pwPeriod + 400)).Contains("63%")) "lecture d'un autre clm : carte dessinee avec la valeur fraiche"
  $pwGap = $pe.NextAt - $pwPeriod - (30 - $pe.U.Age) * 1000
  Assert-True ($pwGap -ge 0 -and $pwGap -lt 3000) ("lecture d'un autre clm : lecture de l'API recalee sur la valeur de la barre, " + $pwGap)
  Assert-True ($pe.Timer[0] -match ('^' + $pwMaj + '(29|3[0-3])s$')) ("lecture d'un autre clm : compteur du menu recale, " + $pe.Timer[0])
  Assert-Null $script:MenuState.Loader "lecture d'un autre clm : aucun appel a l'API pour la valeur de la barre"

  $null = Update-UsageCache { param($map) $map.Remove("fil") }
  $pwDef = Get-PwApiTimer
  Assert-Equal 30 $pwDef[3] "usage-poll absent : lot lu avec 30 s"
  Assert-True ($pwDef[0] -ge 30000 -and $pwDef[0] -lt 33000) ("usage-poll absent : API relue apres 30 s, " + $pwDef[0])
  Assert-True ($pwDef[2] -match ('^' + $pwMaj + '3[0-3]s$')) ("usage-poll absent : compteur " + $pwDef[2])

  Assert-Equal 90 (Set-DisplayUsagePoll 90) "usage-poll 90 : delai ecrit"
  $pwSet = Get-PwApiTimer
  Assert-Equal 90 $pwSet[3] "usage-poll 90 : lot lu avec 90 s"
  Assert-True ($pwSet[0] -ge 90000 -and $pwSet[0] -lt 99000) ("usage-poll 90 : API relue apres 90 s, " + $pwSet[0])
  Assert-True ($pwSet[2] -match ('^' + $pwMaj + '1m(3[05]|40)s$')) ("usage-poll 90 : compteur " + $pwSet[2])
} finally {
  foreach ($n in $pwFaked) { Set-Item ("function:" + $n) $pwKept[$n] }
  foreach ($p in @($pwFiles.Keys)) {
    Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
    if ($null -ne $pwFiles[$p]) { [IO.File]::WriteAllBytes($p, $pwFiles[$p]) }
  }
  $script:MenuState = $pwSaved.Menu; $script:Web = $pwSaved.Web; $script:UiPoll = $pwSaved.Poll; $script:WebOpen = $pwSaved.Open
  $script:WebReopen = $pwSaved.Reopen; $script:DriveJob = $pwSaved.Drive; $script:Startup = $pwSaved.Startup; $script:ClmCheck = $pwSaved.Check
  Remove-Variable -Name PwClock, PwViews -Scope Script -ErrorAction SilentlyContinue
}
