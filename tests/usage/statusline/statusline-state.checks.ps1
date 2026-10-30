$raceLab = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "race"
. (Join-Path $raceLab "race-helpers.ps1")
. (Join-Path $bin "claude-statusline-seed.ps1")
function Get-AccountUsage {
  param($Acc, [switch]$NoRefresh)
  return [PSCustomObject]@{ Error = $null; Pct5 = 42; Reset5 = "2030-01-01T00:00:00Z"; Pct7 = 7; Reset7 = "2030-01-03T00:00:00Z"; Age = 0 }
}
$barState = Get-StatusStatePath
$barDir = Split-Path $barState
$barLock = $barState + ".lock"
$barAcc = [PSCustomObject]@{ Label = "compte1"; Dir = ".claude" }
$barUtf8 = New-Object Text.UTF8Encoding($false)
$barMine = Join-Path $barDir ("state.clm-" + $PID + ".changes")

function Reset-BarState {
  param([string]$Text)
  New-Item -ItemType Directory -Force -Path $barDir | Out-Null
  Get-ChildItem -LiteralPath $barDir -File | Where-Object { $_.Name -ne "state.lock" } | Remove-Item -Force
  [IO.File]::WriteAllText($barState, $Text, $barUtf8)
}

function Read-BarLines {
  param([string]$Path)
  return @([IO.File]::ReadAllText($Path).TrimEnd("`n").Split("`n"))
}

function Start-BarHolder {
  param([int]$HoldMs, [string]$Text = "")
  $flag = Join-Path $script:Sandbox "bar-held"
  if ([IO.File]::Exists($flag)) { [IO.File]::Delete($flag) }
  $kid = Start-RaceChild (Join-Path (Join-Path $raceLab "backup") "hook-bar-holder.ps1") @{ State = $barState; Flag = $flag; HoldMs = $HoldMs; Text = $Text }
  $deadline = [DateTime]::UtcNow.AddMilliseconds($script:RaceReadyMs)
  while (-not [IO.File]::Exists($flag) -and -not $kid.Proc.HasExited -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds $script:RacePollMs }
  return $kid
}

Reset-BarState "theme dark`nq_at@claude 3`n"
Assert-True ((Read-StatusLines $barState) -is [hashtable]) "barre de clm apres chargement du crochet : lecture de l'etat en table de cles"
Update-StatusState $barAcc
$barLines = Read-BarLines $barState
Assert-True ($barLines -contains "theme dark" -and $barLines -contains "q5_pct@claude 42") "etat de la barre : ecrit sous son verrou"
Assert-True ([IO.File]::Exists($barLock)) "verrou de la barre : cree et laisse sur le disque"
Assert-Equal 0 @(Get-ChildItem -LiteralPath $barDir -Filter "*.changes").Count "etat de la barre libre : aucun fichier de changements"

$barWait = $script:StatusStateLockWaitMs
$script:StatusStateLockWaitMs = 5000
Reset-BarState "theme dark`n"
$barHolder = Start-BarHolder 700 "theme dark`nbar 1`n"
Update-StatusState $barAcc
Assert-Equal "" (Format-RaceFailures @(Wait-RaceChild $barHolder)) "verrou tenu par la barre : la barre finit sans erreur"
$barLines = Read-BarLines $barState
Assert-True ($barLines -contains "bar 1") "verrou tenu par la barre : sa ligne gardee"
Assert-True ($barLines -contains "q5_pct@claude 42" -and $barLines -contains "q7_pct@claude 7") "verrou tenu par la barre : clm attend puis ecrit"
Assert-True ([IO.File]::Exists($barLock)) "verrou tenu par la barre : fichier verrou garde"

Reset-BarState "theme dark`nfoo 1`nq5_at@claude 1`nq5_at@autre 5`n"
[IO.File]::WriteAllText((Join-Path $barDir "state.b.changes"), "foo 3`nbaz 9`n", $barUtf8)
[IO.File]::WriteAllText((Join-Path $barDir "state.a.changes"), "foo 2`ntheme`nq5_pct@claude 99`n", $barUtf8)
[IO.File]::WriteAllText((Join-Path $barDir "state.c.changes.tmp"), "foo 7`n", $barUtf8)
Update-StatusState $barAcc
$barLines = Read-BarLines $barState
Assert-True ($barLines -contains "foo 3" -and $barLines -notcontains "foo 2") "changements en attente : appliques dans l'ordre des noms"
Assert-True ($barLines -contains "baz 9" -and $barLines -contains "q5_at@autre 5") "changements en attente : cle ajoutee, autres lignes gardees"
Assert-Equal 0 @($barLines | Where-Object { $_ -match "^theme( |$)" }).Count "changements en attente : cle seule retiree"
Assert-True ($barLines -contains "q5_pct@claude 42" -and $barLines -notcontains "q5_pct@claude 99") "changements en attente : nos valeurs fraiches gagnent"
Assert-Equal "state.c.changes.tmp" ((@(Get-ChildItem -LiteralPath $barDir -File | Where-Object { $_.Name -like "state.*.changes*" }) | ForEach-Object { $_.Name }) -join ",") "changements en attente : appliques puis effaces, le reste laisse"

$script:StatusStateLockWaitMs = 300
Reset-BarState "theme dark`n"
$barHolder = Start-BarHolder 4000
$barErr = $null
try { Update-StatusState $barAcc } catch { $barErr = $_.Exception.Message }
Assert-Null $barErr "barre trop longue a rendre son verrou : abandon sans erreur"
Assert-Equal "theme dark`n" ([IO.File]::ReadAllText($barState)) "barre trop longue a rendre son verrou : etat laisse tel quel"
Assert-True ([IO.File]::Exists($barMine)) "barre trop longue a rendre son verrou : fichier de changements state.clm-<pid>.changes"
$barRaw = ""
if ([IO.File]::Exists($barMine)) { $barRaw = [IO.File]::ReadAllText($barMine) }
$barLines = @($barRaw.TrimEnd("`n").Split("`n"))
Assert-True ($barRaw.EndsWith("`n") -and -not $barRaw.Contains("`r") -and [IO.File]::ReadAllBytes($barMine)[0] -ne 0xEF) "fichier de changements : UTF-8 sans BOM, fins de ligne LF"
Assert-Equal 5 @($barLines | Where-Object { $_ -cmatch "^(q5_at|q5_pct|q7_at|q7_pct|q_at)@claude \S+$" }).Count "fichier de changements : nos cles seulement"
Assert-Equal 5 $barLines.Count "fichier de changements : rien d'autre"
Assert-True ($barLines -contains "q5_pct@claude 42") "fichier de changements : valeurs fraiches"
function Get-AccountUsage {
  param($Acc, [switch]$NoRefresh)
  return [PSCustomObject]@{ Error = $null; Pct5 = 43; Reset5 = "2030-01-01T00:00:00Z"; Pct7 = $null; Reset7 = $null; Age = 0 }
}
Update-StatusState $barAcc
$barLines = @()
if ([IO.File]::Exists($barMine)) { $barLines = Read-BarLines $barMine }
Assert-True ($barLines -contains "q7_at@claude" -and $barLines -contains "q7_pct@claude" -and $barLines -contains "q5_pct@claude 43") "fichier de changements : cles abandonnees en cle seule"
Assert-Equal 0 @(Get-ChildItem -LiteralPath $barDir -Filter "*.tmp").Count "fichier de changements : ecrit par renommage, aucun temporaire laisse"
$null = Wait-RaceChild $barHolder
$script:StatusStateLockWaitMs = $barWait
Update-StatusState $barAcc
$barLines = Read-BarLines $barState
Assert-True ($barLines -contains "q5_pct@claude 43" -and -not [IO.File]::Exists($barMine)) "fichier de changements de clm : repris et efface au passage suivant"
Assert-True ([IO.File]::Exists($barLock)) "verrou de la barre : jamais efface"

. (Join-Path $bin "usage/claude-usage.ps1")
