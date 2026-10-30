$credOs = $script:OsName
if ($credOs -eq "MacOS") { $script:OsName = "Linux" }
function New-TestCred { param([long]$Exp, [string]$Tok = "t") return ('{"claudeAiOauth":{"accessToken":"' + $Tok + '","refreshToken":"r","expiresAt":' + $Exp + ',"scopes":["user:inference"]}}' | ConvertFrom-Json) }
$acc = [PSCustomObject]@{ Label = "ct"; Dir = ".claude-credtest" }
$credPath = Join-Path $script:Sandbox ".claude-credtest/.credentials.json"
$null = New-SandboxFile ".claude-credtest/.claude.json" '{"oauthAccount":{"emailAddress":"a@x.fr"}}'
$fold = @{ Root = "R"; Files = "F"; Credentials = "C"; Presence = "P" }
$script:Sent = New-Object 'System.Collections.Generic.List[object]'
$script:RemoteText = ""
. (Join-Path $PSScriptRoot "fake-creds.ps1")

Assert-Equal 0 (Get-CredentialExpiry $null) "sans jeton, expiration 0"
Assert-Equal "remote" (Select-FresherCredential 100 200) "distant plus frais"
Assert-Equal "local" (Select-FresherCredential 300 200) "local plus frais"
Assert-Equal "same" (Select-FresherCredential 200 200) "egalite"

$listing = @{ ".claude-credtest.json" = @{ Id = "c1"; Exp = 200; Props = @{ exp = "200"; who = "a@x.fr" } } }
$script:RemoteText = ((New-TestCred 200 "distant") | ConvertTo-Json -Depth 10 -Compress)
Assert-Equal "remote" (Sync-AccountCredential $acc $fold $listing) "compte jamais connecte ici : jeton distant pris"
Assert-Equal "distant" (Read-AccountCredential $acc).claudeAiOauth.accessToken "jeton distant ecrit localement"
Assert-Equal 200 (Read-AccountCredential $acc).claudeAiOauth.expiresAt "expiration distante ecrite"

Write-CredentialFile $credPath (New-TestCred 100 "vieux")
Assert-Equal "remote" (Sync-AccountCredential $acc $fold $listing) "jeton distant plus frais pris"
Assert-Equal "distant" (Read-AccountCredential $acc).claudeAiOauth.accessToken "jeton local remplace"
Assert-Equal 0 $script:Sent.Count "rien envoye quand le distant gagne"

Write-CredentialFile $credPath (New-TestCred 500 "local")
Assert-Equal "local" (Sync-AccountCredential $acc $fold $listing) "jeton local plus frais garde"
Assert-Equal "local" (Read-AccountCredential $acc).claudeAiOauth.accessToken "jeton local jamais recule"
Assert-Equal 1 $script:Sent.Count "jeton local envoye"
Assert-Equal "C|.claude-credtest.json|c1|500" ($script:Sent[0].Folder + "|" + $script:Sent[0].Name + "|" + $script:Sent[0].Id + "|" + $script:Sent[0].Props["exp"]) "envoi dans le dossier des jetons, par id, avec l'expiration"
Assert-Equal "local" ($script:Sent[0].Text | ConvertFrom-Json).claudeAiOauth.accessToken "contenu envoye"
$script:Sent.Clear()
Assert-Equal "same" (Sync-AccountCredential $acc $fold @{ ".claude-credtest.json" = @{ Id = "c1"; Exp = 500 } }) "meme expiration, rien a faire"
Assert-Equal 0 $script:Sent.Count "rien envoye a egalite"
$script:Sent.Clear()
$null = Sync-AccountCredential $acc $fold @{}
Assert-Equal "" $script:Sent[0].Id "premier envoi du jeton : nouveau fichier"

Write-CredentialFile $credPath (New-TestCred 100 "tenu")
if ($credOs -ne "Windows") { Assert-Equal "-rw-------" (Get-Item -LiteralPath $credPath -Force).UnixMode "jeton lisible par son seul proprietaire" }
$hold = [IO.File]::Open($credPath, "Open", "ReadWrite", "None")
try { $err = ""; try { $null = Sync-AccountCredential $acc $fold $listing } catch { $err = $_.Exception.Message } } finally { $hold.Dispose() }
Assert-Equal (Get-ClmText "drive.cred.unreadable") $err "jeton local tenu par Claude Code : compte en echec"
Assert-Equal "tenu" (Read-AccountCredential $acc).claudeAiOauth.accessToken "jeton local tenu : jamais remplace"
$script:RemoteText = ((New-TestCred 300 "autre") | ConvertTo-Json -Depth 10 -Compress)
$err = ""; try { $null = Sync-AccountCredential $acc $fold $listing } catch { $err = $_.Exception.Message }
Assert-Equal (Get-ClmText "drive.cred.invalid") $err "jeton du Drive d'une autre expiration : refuse"
$script:RemoteText = '{"claudeAiOauth":{"expiresAt":200}}'
$err = ""; try { $null = Sync-AccountCredential $acc $fold $listing } catch { $err = $_.Exception.Message }
Assert-Equal (Get-ClmText "drive.cred.invalid") $err "jeton du Drive sans jeton d'acces : refuse"
$null = New-SandboxFile ".claude-credtest/.claude.json" '{"oauthAccount":{"emailAddress":"a@x.fr"}}'
$script:RemoteText = ((New-TestCred 200 "intrus") | ConvertTo-Json -Depth 10 -Compress)
$err = ""; try { $null = Sync-AccountCredential $acc $fold @{ ".claude-credtest.json" = @{ Id = "c1"; Exp = 200; Props = @{ exp = "200"; who = "b@y.fr" } } } } catch { $err = $_.Exception.Message }
Assert-Equal (Get-ClmText "drive.cred.otherOwner" @("b@y.fr")) $err "jeton d'une autre adresse : refuse"
Assert-Equal "tenu" (Read-AccountCredential $acc).claudeAiOauth.accessToken "jeton d'une autre adresse : jeton local garde"
$err = ""; try { $null = Sync-AccountCredential $acc $fold @{ ".claude-credtest.json" = @{ Id = "c1"; Exp = 200; Props = @{ exp = "200" } } } } catch { $err = $_.Exception.Message }
Assert-Equal (Get-ClmText "drive.cred.noOwner") $err "jeton du Drive sans adresse : refuse"
$far = [DateTimeOffset]::UtcNow.AddDays(31).ToUnixTimeMilliseconds()
$script:RemoteText = ((New-TestCred $far "lointain") | ConvertTo-Json -Depth 10 -Compress)
$err = ""; try { $null = Sync-AccountCredential $acc $fold @{ ".claude-credtest.json" = @{ Id = "c1"; Exp = $far; Props = @{ exp = ("" + $far); who = "a@x.fr" } } } } catch { $err = $_.Exception.Message }
Assert-Equal (Get-ClmText "drive.cred.tooFar") $err "jeton du Drive valable plus de 30 jours : refuse"
Assert-Equal "tenu" (Read-AccountCredential $acc).claudeAiOauth.accessToken "jetons du Drive refuses : jeton local garde"
$script:RemoteText = ((New-TestCred 200 "intrus") | ConvertTo-Json -Depth 10 -Compress)
$script:Sent.Clear()
Write-CredentialFile $credPath (New-TestCred 600 "moi")
$null = Sync-AccountCredential $acc $fold @{}
Assert-Equal "a@x.fr" $script:Sent[0].Props["who"] "adresse du compte envoyee avec le jeton"
$script:RemoteText = ((New-TestCred 200 "distant") | ConvertTo-Json -Depth 10 -Compress)
Write-CredentialFile $credPath (New-TestCred 100 "vieux")
function Get-DriveBytes { param([string]$Id) Write-CredentialFile $credPath (New-TestCred 900 "claude"); return ,(Get-CredTestBytes) }
$null = Sync-AccountCredential $acc $fold $listing
Assert-Equal "claude" (Read-AccountCredential $acc).claudeAiOauth.accessToken "jeton renouvele par Claude pendant le telechargement : garde"
function Get-DriveBytes { param([string]$Id) return ,(Get-CredTestBytes) }

$now = 1000000
$pres = @{
  "MAC.json" = @{ Props = @{ ".claude" = ("" + ($now - 100)); ".claude-compte2" = ("" + ($now - 13 * 3600)); ".claude-compte4" = "0"; "fmt" = ("" + $script:SyncFormat) } }
  "PC.json" = @{ Props = @{ ".claude-compte3" = ("" + $now) } }
}
$away = Get-AwayMap $pres "PC" $now
Assert-Equal 1 $away.Count "presence : seulement les comptes ouverts ailleurs depuis moins de 12 h"
Assert-Equal "MAC" $away[".claude"] "presence : nom de l'autre PC"
Assert-True (-not (Test-AllPcsCurrent $pres)) "version de synchro : un PC sans marque bloque le retrait"
$pres["vieux.json"] = @{ Props = @{ "fmt" = "2" } }
Assert-Equal "PC,vieux" ((Get-WaitingPcs $pres) -join ",") "PC pas a jour : noms sans extension, tries"
$pres["trois.json"] = @{ Props = @{ "fmt" = "3" } }
Assert-Equal "PC,trois,vieux" ((Get-WaitingPcs $pres) -join ",") "PC au format 3 : pas a jour pour le menage du Drive"
Assert-Equal "PC,vieux" ((Get-WaitingPcs $pres $script:McpFormat) -join ",") "PC au format 3 : a jour pour les MCP par PC"
$pres.Remove("vieux.json")
$pres.Remove("trois.json")
$pres["PC.json"].Props["fmt"] = "" + $script:SyncFormat
Assert-True (Test-AllPcsCurrent $pres) "version de synchro : tous les PC a jour"
$pres["PC.json"].Props["fmt"] = "x"
Assert-Equal 0 (Get-PresenceFormat $pres["PC.json"]) "version de synchro illisible : 0"

$script:Props = $null
function Get-DriveFolders { return @{ Root = "R"; Files = "F"; Credentials = "C"; Presence = "P" } }
function Get-DriveListing { param([string]$FolderId) return @{ ((Get-DrivePcName) + ".json") = @{ Id = "own" } } }
function Set-DriveProps { param([string]$Id, $Props) $script:Props = @($Id, $Props) }
Set-DrivePresence $acc $true
Assert-Equal "own" $script:Props[0] "presence : fichier du PC mis a jour"
Assert-True ([long]$script:Props[1][".claude-credtest"] -gt 1700000000) "presence : heure d'ouverture"
Set-DrivePresence $acc $false
Assert-Equal "0" $script:Props[1][".claude-credtest"] "presence : compte ferme"
Assert-Equal ("" + $script:SyncFormat) $script:Props[1]["fmt"] "presence : version de synchro annoncee"
function Get-DriveListing { param([string]$FolderId) return @{} }
$script:Sent.Clear()
Set-DrivePresence $acc $true
Assert-Equal ("P|" + (Get-DrivePcName) + ".json|") ($script:Sent[0].Folder + "|" + $script:Sent[0].Name + "|" + $script:Sent[0].Id) "presence : fichier cree au premier lancement"
