$raceLab = Split-Path -Parent $PSScriptRoot
. (Join-Path $raceLab "race-helpers.ps1")
$writeChild = Join-Path $PSScriptRoot "shared-cache-child.ps1"

$wrRoot = Join-Path $script:Sandbox "usage-write-race"
$wrGate = Join-Path $wrRoot "gate"
New-Item -ItemType Directory -Path $wrGate -Force | Out-Null
$wrEnv = @{ USERPROFILE = $wrRoot; HOME = $wrRoot; LOCALAPPDATA = (Join-Path $wrRoot "AppData") }
$wrParams = @(foreach ($n in 1..3) { @{ Bin = $bin; Lab = $raceLab; Gate = $wrGate; Id = ("w" + $n); Mode = "write" } })
$wrRuns = Invoke-Race $writeChild $wrParams $wrGate $wrEnv
$wrPath = Join-Path (Join-Path $wrEnv.LOCALAPPDATA "claude-menu") "usage.json"
$wrKeys = @()
if (Test-Path -LiteralPath $wrPath) { $wrKeys = @(([IO.File]::ReadAllText($wrPath) | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $_.Name }) }
Assert-Equal "" (Format-RaceFailures $wrRuns) "trois clm ecrivent le cache en meme temps : aucune erreur"
Assert-Equal 45 $wrKeys.Count "trois clm ecrivent le cache en meme temps : 45 entrees gardees"

$holdDir = Join-Path $wrRoot "hold"
New-Item -ItemType Directory -Path $holdDir -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path $script:UsageCachePath) -Force | Out-Null
$holder = Start-RaceChild $writeChild @{ Bin = $bin; Lab = $raceLab; Gate = $holdDir; Id = "h"; Mode = "hold"; LockPath = ($script:UsageCachePath + ".lock") }
$heldAt = [DateTime]::UtcNow.AddMilliseconds($script:RaceReadyMs)
while (-not [IO.File]::Exists((Join-Path $holdDir "held")) -and -not $holder.Proc.HasExited -and [DateTime]::UtcNow -lt $heldAt) { Start-Sleep -Milliseconds $script:RacePollMs }
Save-UsageEntry "attente" ([PSCustomObject]@{ Pct5 = 1; Reset5 = $null; Pct7 = 2; Reset7 = $null })
$holdRun = Wait-RaceChild $holder
Assert-Equal "" (Format-RaceFailures @($holdRun)) "verrou du cache tenu 4 s : aucune erreur"
$wrMap = Read-UsageCache
Assert-True ($wrMap.ContainsKey("attente")) "verrou du cache tenu 4 s par un autre clm : ecriture faite apres l'attente"
if ($wrMap.ContainsKey("attente")) {
  $wrMap.Remove("attente")
  Write-UsageCache $wrMap
}
