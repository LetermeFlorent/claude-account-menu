. (Join-Path (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "fakes") "fake-drive.ps1")

function Set-RemovePresence {
  param([string]$Pc, [long]$Seen)
  $null = Send-FakePresence ($Pc + ".json") ([Text.Encoding]::UTF8.GetBytes("{}")) @{ ".claude" = ("" + $Seen); fmt = ("" + $script:SyncFormat) }
}

$removeNow = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
Use-Pc "PA"
Set-RemovePresence "PA" $removeNow
Set-RemovePresence "PB" ($removeNow - 60)
Set-RemovePresence "VIEUX" ($removeNow - $script:AwaySeconds - 60)
$removeCat = New-SyncCatalog
foreach ($pc in @("PA", "PB", "VIEUX")) { $removeCat.Pcs[$pc] = New-PcContent }
$removeCat.Pcs["PB"].Erased["outil"] = [long]1000
$removeCat.Pcs["PA"].Os = $script:OsName
$removeCat.Pcs["PA"].Took["PB"] = [long]2000
$removeCat.Pcs["PA"].Took["VIEUX"] = [long]2000
Save-SyncCatalog $removeCat
$null = Update-SyncChoice { param($c) foreach ($pc in @("PB", "VIEUX")) { Add-PcAsk @{ Choice = $c; Pc = $pc; Kind = "skills"; Name = "outil"; On = $false; After = 0 } } }

Assert-Throws { Remove-DrivePc "PA" } (Get-ClmText "drive.pc.removeSelf" @("PA")) "ce PC : suppression refusee"
Assert-True $script:FakePresence.ContainsKey("PA.json") "ce PC : presence gardee"

$removeRes = Remove-DrivePc "PB"
Assert-True $removeRes.Recent "PC vu il y a moins de 12 h : signale"
Assert-True (-not $script:FakePresence.ContainsKey("PB.json")) "presence du PC retiree du Drive"
$removeCat = Read-SyncCatalog
Assert-Equal "PA VIEUX" ((@($removeCat.Pcs.Keys) | Sort-Object) -join " ") "PC retire du catalogue"
Assert-True (-not (Get-ErasedSkills $removeCat.Pcs).ContainsKey("outil")) "effacements du PC retires"
Assert-Equal "VIEUX" (@($removeCat.Pcs["PA"].Took.Keys) -join " ") "prise en compte du PC retiree"
Assert-Equal "VIEUX" (@((Read-SyncChoice).Asks.Keys) -join " ") "demandes vers le PC retirees"

$removeRes = Remove-DrivePc "VIEUX"
Assert-True (-not $removeRes.Recent) "PC absent depuis plus de 12 h : pas signale"
Assert-Equal "PA.json" (@($script:FakePresence.Keys) -join " ") "seule la presence de ce PC reste"
Assert-Equal 0 (Read-SyncChoice).Asks.Count "plus aucune demande"

$script:Fake.Clear()
$script:FakePresence.Clear()
Restore-FakeDrive
