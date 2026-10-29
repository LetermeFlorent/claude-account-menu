. (Join-Path $bin "claude-menu-loop.ps1")
. (Join-Path $bin "claude-menu-startup.ps1")
. (Join-Path $bin "claude-cli.ps1")
$restartMocked = @("Get-ClmSha", "Read-UiKey", "Get-WebAction")
$restartKept = @{}
foreach ($n in $restartMocked) { $restartKept[$n] = (Get-Item ("function:" + $n)).ScriptBlock }
$restartLoaded = $script:ClmLoadedSha
$script:RestartDiskSha = ""
function Get-ClmSha { param([string]$Dir = "") return $script:RestartDiskSha }
function Read-UiKey { return $null }
function Get-WebAction { return $null }

function Reset-ClmRestart {
  param([string]$Disk)
  $script:ClmLoadedSha = "a" * 40
  $script:RestartDiskSha = $Disk
  $script:ClmRestartDue = $false
  $script:ClmRestartAt = 0.0
  $script:ClmUpdated = $false
  $script:UiQuit = $false
  $script:Startup = $null
  $script:DriveJob = $null
}

try {
  Reset-ClmRestart ("a" * 40)
  Step-ClmRestart 1000
  Assert-True (-not $script:ClmRestartDue) "meme version sur le disque : pas de redemarrage"
  $script:RestartDiskSha = "b" * 40
  Step-ClmRestart 1500
  Assert-True (-not $script:ClmRestartDue) "nouvelle version posee : pas relue avant une seconde"
  Step-ClmRestart (1000 + $script:ClmReplacedPollMs)
  Assert-True $script:ClmRestartDue "nouvelle version posee par un autre clm : redemarrage prevu"

  Reset-ClmRestart ("b" * 40)
  $script:Startup = New-Startup @("claude")
  Step-ClmRestart 1000
  Assert-True (-not $script:ClmRestartDue) "nouvelle version pendant le lancement : redemarrage attendu"
  $script:Startup = $null
  $script:DriveJob = New-DriveJob $false 0
  $script:DriveJob.Loader = @{ Ctl = @{ Done = $false } }
  Step-ClmRestart 3000
  Assert-True (-not $script:ClmRestartDue) "nouvelle version pendant une synchro Drive : redemarrage attendu"
  $script:DriveJob = $null
  Step-ClmRestart 5000
  Assert-True $script:ClmRestartDue "synchro Drive finie : redemarrage prevu"

  Reset-ClmRestart ""
  Step-ClmRestart 1000
  Assert-True (-not $script:ClmRestartDue) "version illisible pendant une installation : pas de redemarrage"

  Reset-ClmRestart ("b" * 40)
  Assert-True (-not (Step-ClmCheck $null 1000)) "verification coupee : rien a redessiner"
  Assert-True $script:ClmRestartDue "verification coupee : nouvelle version quand meme reperee"

  Reset-ClmRestart ("a" * 40)
  Assert-Equal "up" (Get-ClmRestartAction @{ Name = "up" }).Name "pas de nouvelle version : touche gardee"
  Assert-Equal "none" (Get-ClmRestartAction @{ Name = "none" }).Name "pas de nouvelle version : menu garde"
  Assert-True (-not $script:ClmUpdated) "pas de nouvelle version : pas de redemarrage"
  $script:ClmRestartDue = $true
  Assert-Equal "launch" (Get-ClmRestartAction @{ Name = "launch" }).Name "nouvelle version et Entree : Entree passe d'abord"
  Assert-True (-not $script:ClmUpdated) "nouvelle version et Entree : pas de redemarrage sous le compte"
  Assert-Equal "restart" (Get-ClmRestartAction @{ Name = "none" }).Name "nouvelle version, menu au repos : menu ferme"
  Assert-True $script:ClmUpdated "nouvelle version, menu au repos : redemarrage demande"
  $script:ClmUpdated = $false
  $script:DriveJob = New-DriveJob $false 0
  $script:DriveJob.Loader = @{ Ctl = @{ Done = $false } }
  Assert-Equal "none" (Get-ClmRestartAction @{ Name = "none" }).Name "synchro Drive lancee apres la nouvelle version : redemarrage attendu"
  $script:DriveJob = $null
  $script:Startup = New-Startup @()
  $script:Startup.Pending = @{ Name = "pick"; Index = 1 }
  Assert-Equal "none" (Get-ClmRestartAction @{ Name = "none" }).Name "compte choisi pendant le lancement : ouvert avant tout redemarrage"
  Assert-True (-not $script:ClmUpdated) "compte choisi pendant le lancement : pas de redemarrage demande"
  $script:Startup = $null

  Reset-ClmRestart ("a" * 40)
  $restartState = @{ Entries = @(@{ Acc = [PSCustomObject]@{ Label = "a" } }) }
  Assert-Equal "none" (Read-MenuAction $restartState).Name "menu au repos sans nouvelle version : rien"
  $script:ClmRestartDue = $true
  Assert-Equal "restart" (Read-MenuAction $restartState).Name "menu au repos avec nouvelle version : redemarrage"
  Assert-Equal "restart" (Read-MenuAction @{ Entries = @() }).Name "menu sans compte avec nouvelle version : redemarrage"

  Assert-Equal "--continue --no-update" ((Get-ClmRestartArgs @("-2", "--continue", "--updated", "--yes", "--only=a", "--restore=x.zip")) -join " ") "redemarrage : compte direct et actions uniques retires"
  Assert-Equal "--web --no-update" ((Get-ClmRestartArgs @("--web", "--no-update", "--usage", "--save=b", "--update", "--list", "--sync", "--force", "--drive-login", "--sync-auto=on", "--erase")) -join " ") "redemarrage : commandes et synchro retirees, page web gardee"
  Assert-Equal "--no-update" ((Get-ClmRestartArgs @()) -join " ") "redemarrage sans argument : pas de nouvelle mise a jour"
  Assert-Equal "--no-update" ((Get-ClmRestartArgs @("--no-update", "--no-update")) -join " ") "redemarrage : --no-update jamais double"
} finally {
  foreach ($n in $restartMocked) { Set-Item -Path ("function:script:" + $n) -Value $restartKept[$n] }
  $script:ClmLoadedSha = $restartLoaded
  $script:ClmRestartDue = $false
  $script:ClmRestartAt = 0.0
  $script:ClmUpdated = $false
  $script:UiQuit = $false
  $script:Startup = $null
  $script:DriveJob = $null
  Remove-Item -Path "function:Reset-ClmRestart" -ErrorAction SilentlyContinue
}
