. (Join-Path (Split-Path -Parent $PSScriptRoot) "race-helpers.ps1")

$writeChild = @'
param([string]$Bin, [string]$Lab, [string]$Dir, [string]$Id, [int]$Rounds)
$ErrorActionPreference = "Stop"
. (Join-Path $Lab "race-helpers.ps1")
. (Join-Path $Bin "claude-import.ps1")
. Import-ClmModule claude-json
$target = Join-Path $Dir "shared.json"
Wait-RaceGate $Dir $Id
for ($i = 0; $i -lt $Rounds; $i++) {
  Write-TextFileAtomic $target ('{"id":"' + $Id + '","n":' + $i + '}')
  $back = Read-JsonFile $target
  if ([string]::IsNullOrEmpty([string]$back["id"])) { throw "lecture vide" }
}
"ok " + $Id
'@

$raceDir = Join-Path $script:Sandbox "race-write"
New-Item -ItemType Directory -Path $raceDir -Force | Out-Null
$writeScript = New-SandboxFile "race-write-child.ps1" $writeChild
$writers = @(foreach ($n in 1..3) { @{ Bin = $bin; Lab = (Split-Path -Parent $PSScriptRoot); Dir = $raceDir; Id = ("w" + $n); Rounds = 300 } })
$writeRuns = Invoke-Race $writeScript $writers $raceDir
Assert-Equal "" (Format-RaceFailures $writeRuns) "trois clm ecrivent et relisent le meme fichier : aucune erreur"
Assert-Equal "ok w1 ok w2 ok w3" (@($writeRuns | ForEach-Object { $_.Out }) -join " ") "trois clm ecrivent et relisent le meme fichier : chacun va au bout"
$left = @(Get-ChildItem -LiteralPath $raceDir -Filter "*.tmp")
Assert-Equal 0 $left.Count "trois clm ecrivent le meme fichier : aucun temporaire laisse"
$final = Read-JsonFile (Join-Path $raceDir "shared.json")
Assert-Equal "299" ("" + $final["n"]) "trois clm ecrivent le meme fichier : le fichier final est entier"

function global:Stop-RaceTestPath { throw (New-Object UnauthorizedAccessException "Access is denied") }
$busyPath = Join-Path $raceDir "busy.json"
[IO.File]::WriteAllText($busyPath, '{"id":"busy"}')
Set-Alias -Name Test-Path -Value Stop-RaceTestPath -Scope Global -Force
try { $busy = Read-JsonFile $busyPath; $gone = Read-JsonFile (Join-Path $raceDir "gone.json") } catch { $busy = @{ id = "error " + $_.Exception.Message }; $gone = "error" } finally { Remove-Item -LiteralPath Alias:Test-Path -Force; Remove-Item -LiteralPath Function:Stop-RaceTestPath -Force }
Assert-Equal "busy" ("" + $busy["id"]) "un fichier que Windows refuse de tester pendant un remplacement se relit quand meme"
Assert-True ($null -eq $gone) "un fichier absent se relit comme vide"
