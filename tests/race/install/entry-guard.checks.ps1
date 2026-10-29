$raceLab = Split-Path -Parent $PSScriptRoot
. (Join-Path $raceLab "race-helpers.ps1")

$egRoot = Join-Path $script:Sandbox "entry-guard"
$egV1 = "1111111111111111111111111111111111111111 1760000000 5"
$egV2 = "2222222222222222222222222222222222222222 1770000000 6"
$egWaitMs = 60000
$egQuiet = "code 0 | sortie [] | erreurs []"
$egLoadLines = @'
$egSeen = @(if ([IO.File]::Exists('LOADS')) { [IO.File]::ReadAllLines('LOADS') }); if ($egSeen.Count -ge 3) { exit 3 }
[IO.File]::AppendAllText('LOADS', [Environment]::CommandLine + [Environment]::NewLine)
[IO.File]::WriteAllText([IO.Path]::Combine($PSScriptRoot, 'clm.version'), [guid]::NewGuid().ToString('N') + '00000000 1770000000 ' + $egSeen.Count)
'@

function New-GuardCase {
  param([string]$Name, [switch]$Installing)
  $root = Join-Path $egRoot $Name
  $copy = Join-Path $root "bin"
  New-Item -ItemType Directory -Path $copy -Force | Out-Null
  Copy-Item -Path (Join-Path $bin "*") -Destination $copy -Recurse -Force
  [IO.File]::WriteAllText((Join-Path $copy "clm.version"), $egV1 + "`n")
  if ($Installing) { [IO.File]::WriteAllText((Join-Path $copy "clm.installing"), "x") }
  $data = Join-Path $root "AppData"
  $vars = @{ USERPROFILE = $root; HOME = $root; LOCALAPPDATA = (Join-Path $data "Local"); APPDATA = (Join-Path $data "Roaming"); CLAUDE_CONFIG_DIR = $null; CLAUDECODE = $null; CLAUDE_CODE_ENTRYPOINT = $null }
  return [PSCustomObject]@{ Root = $root; Bin = $copy; Env = $vars; Ran = (Join-Path $root "ran") }
}

function Set-GuardFile {
  param($Case, [string]$Name, [string]$Text)
  [IO.File]::WriteAllText((Join-Path $Case.Bin $Name), $Text + "`r`n")
}

function Edit-GuardFile {
  param($Case, [string]$Name, [string]$First, [string]$Last = "")
  $text = [IO.File]::ReadAllText((Join-Path $bin $Name))
  Set-GuardFile $Case $Name ($First + "`r`n" + $text + "`r`n" + $Last)
}

function Get-GuardStampLine {
  return "[IO.File]::WriteAllText([IO.Path]::Combine(`$PSScriptRoot, 'clm.version'), '" + $egV2 + "')"
}

function Get-GuardRanLine {
  param($Case, [string]$Function)
  return "function " + $Function + " { [IO.File]::WriteAllText('" + $Case.Ran + "', 'ran') }"
}

function Invoke-GuardChild {
  param($Case, [string]$Name, [string[]]$Argv = @())
  $line = (Join-Path $Case.Bin $Name) + (@($Argv | ForEach-Object { '" "' + $_ }) -join "")
  return Start-RaceChild $line @{} $Case.Env
}

function Format-GuardRun {
  param($Run, [switch]$Loud)
  if ($Loud) { return "code " + $Run.Code + " | erreurs [" + $Run.Err + "]" }
  return "code " + $Run.Code + " | sortie [" + $Run.Out + "] | erreurs [" + $Run.Err + "]"
}

function Read-GuardLoads {
  param([string]$Path)
  if (-not [IO.File]::Exists($Path)) { return @() }
  return @([IO.File]::ReadAllLines($Path))
}

$egA = New-GuardCase "watcher-installing" -Installing
Set-GuardFile $egA "claude-drive-watch.ps1" "throw 'melange'"
$egRun = Wait-RaceChild (Invoke-GuardChild $egA "claude-drive-watcher.ps1") $egWaitMs
Assert-Equal $egQuiet (Format-GuardRun $egRun) "veilleur pendant une installation : sortie sans bruit"

$egB = New-GuardCase "watcher-replaced"
Edit-GuardFile $egB "claude-drive-watch.ps1" (Get-GuardStampLine) (Get-GuardRanLine $egB "Invoke-DriveWatch")
$egRun = Wait-RaceChild (Invoke-GuardChild $egB "claude-drive-watcher.ps1") $egWaitMs
Assert-Equal $egQuiet (Format-GuardRun $egRun) "veilleur remplace pendant son chargement : sortie sans bruit"
Assert-True (-not [IO.File]::Exists($egB.Ran)) "veilleur remplace pendant son chargement : aucun travail"

$egC = New-GuardCase "hook-installing" -Installing
Set-GuardFile $egC "claude-usage.ps1" "throw 'melange'"
$egRun = Wait-RaceChild (Invoke-GuardChild $egC "claude-statusline-seed.ps1") $egWaitMs
Assert-Equal $egQuiet (Format-GuardRun $egRun) "crochet de session pendant une installation : sortie sans bruit"

$egD = New-GuardCase "hook-replaced"
Edit-GuardFile $egD "claude-usage.ps1" (Get-GuardStampLine) (Get-GuardRanLine $egD "Get-Accounts")
$egRun = Wait-RaceChild (Invoke-GuardChild $egD "claude-statusline-seed.ps1") $egWaitMs
Assert-Equal $egQuiet (Format-GuardRun $egRun) "crochet de session remplace pendant son chargement : sortie sans bruit"
Assert-True (-not [IO.File]::Exists($egD.Ran)) "crochet de session remplace pendant son chargement : aucun travail"

$egE = New-GuardCase "menu-wait" -Installing
$egStarted = Join-Path $egE.Root "started"
Edit-GuardFile $egE "claude-import.ps1" ("[IO.File]::WriteAllText('" + $egStarted + "', 'x')")
Set-GuardFile $egE "claude-usage.ps1" "throw 'melange'"
$egKid = Invoke-GuardChild $egE "claude-menu.ps1" "--help"
$egUntil = [DateTime]::UtcNow.AddSeconds(30)
while (-not [IO.File]::Exists($egStarted) -and [DateTime]::UtcNow -lt $egUntil) { Start-Sleep -Milliseconds 50 }
Start-Sleep -Milliseconds 1500
Copy-Item -LiteralPath (Join-Path $bin "claude-usage.ps1") -Destination (Join-Path $egE.Bin "claude-usage.ps1") -Force
[IO.File]::WriteAllText((Join-Path $egE.Bin "clm.version"), $egV2 + "`n")
Remove-Item -LiteralPath (Join-Path $egE.Bin "clm.installing") -Force
$egRun = Wait-RaceChild $egKid $egWaitMs
Assert-Equal "code 0 | erreurs []" (Format-GuardRun $egRun -Loud) "menu pendant une installation : attend puis demarre sans erreur"
Assert-True ($egRun.Out.Contains("--list")) "menu pendant une installation : aide affichee"

$egF = New-GuardCase "menu-reload"
$egLoads = Join-Path $egF.Root "loads"
Edit-GuardFile $egF "claude-cli.ps1" $egLoadLines.Replace("LOADS", $egLoads)
$egRun = Wait-RaceChild (Invoke-GuardChild $egF "claude-menu.ps1" "--help") $egWaitMs
$egSeen = @(Read-GuardLoads $egLoads)
Assert-Equal "code 0 | erreurs []" (Format-GuardRun $egRun -Loud) "menu remplace pendant son chargement : sans erreur"
Assert-True ($egRun.Out.Contains("--list")) "menu remplace pendant son chargement : aide affichee"
Assert-Equal 2 $egSeen.Count "menu remplace pendant son chargement : recharge une seule fois"
Assert-True ($egSeen.Count -ge 2 -and $egSeen[1].Contains("--updated")) "menu remplace pendant son chargement : relance avec --updated"
