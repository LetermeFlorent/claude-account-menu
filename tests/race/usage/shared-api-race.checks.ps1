$raceLab = Split-Path -Parent $PSScriptRoot
. (Join-Path $raceLab "race-helpers.ps1")
$usageChild = Join-Path $PSScriptRoot "shared-api-child.ps1"

function New-UsageRaceBox {
  param([string]$Name)
  $root = Join-Path $script:Sandbox $Name
  foreach ($d in @("calls", "gate1", "gate2")) { New-Item -ItemType Directory -Path (Join-Path $root $d) -Force | Out-Null }
  return [PSCustomObject]@{ Root = $root; Env = @{ USERPROFILE = $root; HOME = $root; LOCALAPPDATA = (Join-Path $root "AppData") } }
}

function Invoke-UsageRace {
  param($Box, [string]$Gate, [string]$Mode, [string[]]$Ids)
  $gateDir = Join-Path $Box.Root $Gate
  $params = @(foreach ($id in $Ids) { @{ Bin = $bin; Lab = $raceLab; Gate = $gateDir; Calls = (Join-Path $Box.Root "calls"); Id = $id; Mode = $Mode } })
  return Invoke-Race $usageChild $params $gateDir $Box.Env
}

function Get-UsageRaceCalls {
  param($Box)
  return @(Get-ChildItem -LiteralPath (Join-Path $Box.Root "calls") -Filter "call-*").Count
}

function Get-UsageRaceRows {
  param($Runs)
  return @(foreach ($r in $Runs) { foreach ($l in @($r.Out -split "`r?`n" | Where-Object { $_ -like "result *" })) { , ($l -split " ") } })
}

$sameBox = New-UsageRaceBox "usage-race-same"
$sameRuns = Invoke-UsageRace $sameBox "gate1" "ok" @("a1", "a2", "a3")
Assert-Equal "" (Format-RaceFailures $sameRuns) "trois clm lisent le meme compte : aucune erreur"
Assert-Equal 1 (Get-UsageRaceCalls $sameBox) "trois clm lisent le meme compte : un seul appel a l'API"
Assert-Equal "42 42 42" ((@(Get-UsageRaceRows $sameRuns | ForEach-Object { $_[2] }) | Sort-Object) -join " ") "trois clm lisent le meme compte : tous ont les chiffres"

$refBox = New-UsageRaceBox "usage-race-refus"
$refCache = Join-Path (Join-Path $refBox.Env.LOCALAPPDATA "claude-menu") "usage.json"
New-Item -ItemType Directory -Path (Split-Path $refCache) -Force | Out-Null
$refOld = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - 1000
[IO.File]::WriteAllText($refCache, ('{ "course": { "At": ' + $refOld + ', "Pct5": 15, "Reset5": "2030-01-01T00:00:00Z", "Pct7": 2, "Reset7": "2030-01-03T00:00:00Z", "Fails": 0, "Until": 0 } }'), (New-Object Text.UTF8Encoding($false)))
$refFirst = Invoke-UsageRace $refBox "gate1" "refuse" @("b1")
$refLater = Invoke-UsageRace $refBox "gate2" "refuse" @("b2", "b3")
$refNow = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
Assert-Equal "" (Format-RaceFailures (@($refFirst) + @($refLater))) "refus 429 : aucune erreur"
Assert-Equal 1 (Get-UsageRaceCalls $refBox) "refus 429 : un seul appel, les clm suivants respectent la pause"
$refRows = @(Get-UsageRaceRows (@($refFirst) + @($refLater)))
Assert-Equal 3 $refRows.Count "refus 429 : trois resultats"
foreach ($row in $refRows) {
  $left = [long]$row[3] - $refNow
  Assert-True ($left -ge 280 -and $left -le 306) ("refus 429 : pause de 300 s pour " + $row[1] + " (" + $left + ")")
  Assert-Equal 15 $row[2] ("refus 429 : chiffres connus gardes pour " + $row[1])
}
