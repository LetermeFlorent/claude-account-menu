Assert-Null (Get-DriveCliAction @("-2", "--resume")) "options de Claude : pas une action Drive"
Assert-Null (Get-DriveCliAction @()) "sans option : pas une action Drive"
Assert-Equal "login" (Get-DriveCliAction @("--drive-login")).Name "connexion au Drive"
$a = Get-DriveCliAction @("--sync")
Assert-True ($a.Name -eq "sync" -and -not $a.Force) "synchro manuelle"
Assert-True (Get-DriveCliAction @("--force", "--sync")).Force "synchro forcee, ordre libre"
$a = Get-DriveCliAction @("--sync-auto=off")
Assert-True ($a.Name -eq "auto" -and -not $a.On) "synchro auto coupee"
Assert-True (Get-DriveCliAction @("--sync-auto=on")).On "synchro auto activee"
Assert-Equal "error" (Get-DriveCliAction @("--sync-auto=oui")).Name "valeur inconnue refusee"

$cliCfg = $script:DriveConfigPath
$script:DriveConfigPath = Join-Path $script:Sandbox "cli-drive.json"
Assert-Equal 1 (Invoke-DriveCli @{ Name = "sync"; Force = $false }) "--sync sans Drive : echec"
Assert-Equal 1 (Invoke-DriveCli @{ Name = "error"; Msg = "x" }) "option invalide : echec"
Assert-Equal 0 (Invoke-DriveCli @{ Name = "auto"; On = $false }) "--sync-auto=off : reussi"
Assert-Equal $false (Read-DriveConfig)["auto"] "--sync-auto=off : reglage ecrit"

$script:CliCalls = New-Object 'System.Collections.Generic.List[string]'
function Set-DrivePresence { param($Acc, [bool]$Open) $script:CliCalls.Add("presence " + $Open) }
function Send-DriveCredential { param($Acc) $script:CliCalls.Add("jeton") }
function Invoke-DriveSync { param($Ctl = $null, [long]$DeadlineMs = 0, [switch]$Force) $script:CliCalls.Add("sync " + $DeadlineMs + " " + $Force.IsPresent + " " + [bool]$Ctl.Echo); return @{ Ok = $true; Error = ""; Up = 0; Down = 0; Deleted = 0; Conflicts = 0; Left = 2 } }
$acc = [PSCustomObject]@{ Label = "c"; Dir = ".claude" }
Remove-Item -LiteralPath $script:DriveConfigPath -Force
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
