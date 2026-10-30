$pwSaved = @{ Menu = $script:MenuState; Web = $script:Web; Poll = $script:UiPoll; Open = $script:WebOpen; Reopen = $script:WebReopen; Drive = $script:DriveJob; Startup = $script:Startup; Check = $script:ClmCheck }
. (Join-Path $bin "claude-menu-loop.ps1")
. (Join-Path $bin "claude-menu-remove.ps1")
. (Join-Path $bin "claude-cli.ps1")

$pwFaked = @("Get-NowMs", "Start-UsageLoader", "Start-WebServer", "Open-Browser")
$pwKept = @{}
foreach ($n in $pwFaked) { $pwKept[$n] = (Get-Item ("function:" + $n)).ScriptBlock }
$pwBar = Get-StatusStatePath
$pwFiles = @{}
foreach ($p in @($pwBar, (Get-DisplayPath))) { $pwFiles[$p] = $null; if ([IO.File]::Exists($p)) { $pwFiles[$p] = [IO.File]::ReadAllBytes($p) } }
$pwUnix = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$pwAccs = @([PSCustomObject]@{ Label = "fil"; Dir = ".claude-fil" }, [PSCustomObject]@{ Label = "fil2"; Dir = ".claude-fil2" })
$pwUtf8 = New-Object Text.UTF8Encoding($false)
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
    $u.Age = 0; $u.At = $pwUnix - 30
    $q.Enqueue(@($i, $u, $null))
    $i++
  }
  return @{ Ps = $null; Ctl = @{ Done = $true; Error = $null }; Queue = $q }
}

function Start-WebServer { param([hashtable]$Views) $script:PwViews = $Views; return $null }
function Open-Browser { param([string]$Url) return $true }

function Write-PwBar {
  param([int]$Pct5)
  $at = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $lines = @("theme dark", ("q_at@claude-fil " + $at), ("q5_at@claude-fil " + ($pwUnix + 3600)), ("q5_pct@claude-fil " + $Pct5), ("q7_at@claude-fil " + ($pwUnix + 86400)), "q7_pct@claude-fil 3")
  [IO.File]::WriteAllText($pwBar, (($lines -join "`n") + "`n"), $pwUtf8)
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
  $slot = $s.Entries[1].Slot
  Start-MenuLoader $s
  Step-MenuLoader $s (Get-NowMs)
  $null = Update-MenuTimers $s (Get-NowMs)
  return @(($s.Entries[0].NextAt - (Get-NowMs)), $slot, $s.Entries[0].Timer[0], $s.PollSec)
}

try {
  $script:Web = $null; $script:DriveJob = $null; $script:Startup = $null; $script:ClmCheck = $null
  foreach ($p in @($pwFiles.Keys)) { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue }
  New-Item -ItemType Directory -Force -Path (Split-Path $pwBar) | Out-Null
  $pwPeriod = [double]$script:LiveCheckMs
  Assert-Equal 2000 $pwPeriod "fil de la barre : fichier relu toutes les 2 s"

  $script:MenuState = New-MenuState @($pwAccs[0]) (Get-NowMs) $false
  Start-MenuLoader $script:MenuState
  Open-MenuWeb $script:MenuState
  $script:WebOpen = $true
  Assert-True ($null -ne $script:PwViews -and $script:PwViews.ContainsKey("state")) "fil de la barre : vue state branchee par Open-MenuWeb"
  $pe = $script:MenuState.Entries[0]
  Step-PwFrame 0
  Assert-Equal 7 $pe.U.Pct5 "fil de la barre : carte remplie par l'API simulee"
  Assert-Equal 7 (Read-PwWeb) "fil de la barre : page web remplie par l'API simulee"

  $script:PwClock = 100.0
  Write-PwBar 63
  foreach ($t in @(1000.0, ($pwPeriod - 1))) {
    Step-PwFrame $t
    Assert-Equal 7 $pe.U.Pct5 ("fil de la barre : carte inchangee a " + $t + " ms")
    Assert-Equal 7 (Read-PwWeb) ("fil de la barre : page web inchangee a " + $t + " ms")
  }
  Assert-True ((Read-PwCard $pe ($pwPeriod - 1)).Contains(" 7%")) "fil de la barre : carte dessinee avec l'ancienne valeur avant 2 s"

  Step-PwFrame $pwPeriod
  Assert-Equal 63 $pe.U.Pct5 "fil de la barre : valeur fraiche dans la carte a 2 s"
  Assert-Equal 63 $pe.T5.To "fil de la barre : barre 5h animee vers la valeur fraiche"
  Assert-Equal 63 (Read-PwWeb) "fil de la barre : valeur fraiche dans la page web a 2 s"
  Assert-True ((Read-PwCard $pe ($pwPeriod + 400)).Contains("63%")) "fil de la barre : carte dessinee avec la valeur fraiche"
  $pwGap = $pe.NextAt - $pwPeriod - (30 - $pe.U.Age) * 1000
  Assert-True ($pwGap -ge 0 -and $pwGap -lt 3000) ("fil de la barre : lecture de l'API recalee sur la valeur de la barre, " + $pwGap)
  Assert-True ($pe.Timer[0] -match ('^' + $pwMaj + '(29|3[0-3])s$')) ("fil de la barre : compteur du menu recale, " + $pe.Timer[0])
  Assert-Null $script:MenuState.Loader "fil de la barre : aucun appel a l'API pour la valeur de la barre"

  Remove-Item -LiteralPath $pwBar -Force
  $pwDef = Get-PwApiTimer
  Assert-Equal 30 $pwDef[3] "usage-poll absent : lot lu avec 30 s"
  Assert-True ($pwDef[0] -ge 30000 -and $pwDef[0] -lt 33000) ("usage-poll absent : API relue apres 30 s, " + $pwDef[0])
  Assert-Equal 15000 $pwDef[1] "usage-poll absent : second compte decale de 15 s"
  Assert-True ($pwDef[2] -match ('^' + $pwMaj + '3[0-3]s$')) ("usage-poll absent : compteur " + $pwDef[2])

  $pwCode = Invoke-CliCommand (Get-CliCommand @("--usage-poll", "90")) @("--usage-poll", "90") 6>$null
  Assert-Equal 0 $pwCode "usage-poll 90 : commande reussie"
  $pwSet = Get-PwApiTimer
  Assert-Equal 90 $pwSet[3] "usage-poll 90 : lot lu avec 90 s"
  Assert-True ($pwSet[0] -ge 90000 -and $pwSet[0] -lt 99000) ("usage-poll 90 : API relue apres 90 s, " + $pwSet[0])
  Assert-Equal 45000 $pwSet[1] "usage-poll 90 : second compte decale de 45 s"
  Assert-True ($pwSet[2] -match ('^' + $pwMaj + '1m3[0-9]s$')) ("usage-poll 90 : compteur " + $pwSet[2])
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
