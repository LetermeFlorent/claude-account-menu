Assert-Null (Get-DriveCliAction @("-2", "--resume")) "options de Claude : pas une action Drive"
Assert-Null (Get-DriveCliAction @()) "sans option : pas une action Drive"
$a = Get-DriveCliAction @("--sync")
Assert-True ($a.Name -eq "sync" -and -not $a.Force) "synchro manuelle"
Assert-True (Get-DriveCliAction @("--force", "--sync")).Force "synchro forcee, ordre libre"
Assert-Equal "key" (Get-DriveCliAction @("--sync-key")).Name "phrase de synchro"
Assert-Equal "key-reset" (Get-DriveCliAction @("--sync-key-reset")).Name "nouvelle phrase"
Assert-Equal "key-forget" (Get-DriveCliAction @("--sync-key-forget")).Name "phrase oubliee"
Assert-Null (Get-DriveCliAction @("--drive-login")) "connexion au Drive : plus en ligne de commande"
Assert-Null (Get-DriveCliAction @("--sync-auto=on")) "synchro auto : plus en ligne de commande"

$cliCfg = $script:DriveConfigPath
$script:DriveConfigPath = Join-Path $script:Sandbox "cli-drive.json"
Assert-Equal 1 (Invoke-DriveCli @{ Name = "sync"; Force = $false }) "--sync sans Drive : echec"

$script:CliCalls = New-Object 'System.Collections.Generic.List[string]'
function Set-DrivePresence { param($Acc, [bool]$Open) $script:CliCalls.Add("presence " + $Open) }
function Send-DriveCredential { param($Acc) $script:CliCalls.Add("jeton") }
function Invoke-DriveSync { param($Ctl = $null, [long]$DeadlineMs = 0, [switch]$Force) $script:CliCalls.Add("sync " + $DeadlineMs + " " + $Force.IsPresent + " " + [bool]$Ctl.Echo); return @{ Ok = $true; Error = ""; Up = 0; Down = 0; Deleted = 0; Conflicts = 0; Left = 2 } }
$acc = [PSCustomObject]@{ Label = "c"; Dir = ".claude" }
Remove-Item -LiteralPath $script:DriveConfigPath -Force -ErrorAction SilentlyContinue
Sync-DriveAfterExit $acc 5
Assert-Equal 0 $script:CliCalls.Count "fermeture sans Drive : rien"
Save-DriveConfig @{ refreshToken = "r"; auto = $false }
Sync-DriveAfterExit $acc 5
Assert-Equal "presence False|jeton" ($script:CliCalls -join "|") "fermeture, synchro auto coupee : presence retiree et jeton envoye"
$script:CliCalls.Clear()
Set-DriveAuto $true
Sync-DriveAfterExit $acc 5
Assert-Equal "presence False|sync 5 False False" ($script:CliCalls -join "|") "fermeture : synchro bornee par l'echeance"
$script:CliCalls.Clear()
Assert-Equal 0 (Invoke-DriveCli @{ Name = "sync"; Force = $true }) "--sync --force : reussi"
Assert-Equal "sync 0 True True" $script:CliCalls[0] "--sync : forcee, sans echeance, progression affichee"
$global:LASTEXITCODE = 7
$script:CliCalls.Clear()
Stop-DriveSession $acc
Assert-Equal 7 $global:LASTEXITCODE "code de sortie de Claude garde"
Assert-True ($script:CliCalls[1] -match "^sync \d{13} ") "fermeture : echeance a 30 secondes"

Remove-Item -LiteralPath $script:DriveConfigPath -Force
$script:DriveConfigPath = $cliCfg
. (Join-Path $bin "drive/sync/claude-drive-sync.ps1")
