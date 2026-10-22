$credOs = $script:OsName
if ($credOs -eq "MacOS") { $script:OsName = "Linux" }
function New-TestCred { param([long]$Exp, [string]$Tok = "t") return ('{"claudeAiOauth":{"accessToken":"' + $Tok + '","refreshToken":"r","expiresAt":' + $Exp + ',"scopes":["user:inference"]}}' | ConvertFrom-Json) }
$acc = [PSCustomObject]@{ Label = "ct"; Dir = ".claude-credtest" }
$credPath = Join-Path $script:Sandbox ".claude-credtest/.credentials.json"
$fold = @{ Root = "R"; Files = "F"; Credentials = "C"; Presence = "P" }
$script:Sent = New-Object 'System.Collections.Generic.List[object]'
$script:RemoteText = ""
function Get-DriveText { param([string]$Id) return $script:RemoteText }
function Send-DriveText { param([string]$FolderId, [string]$Name, [string]$Text, $Props, [string]$Id) $script:Sent.Add(@{ Folder = $FolderId; Name = $Name; Text = $Text; Props = $Props; Id = $Id }); return @{ Id = "n"; Md5 = "" } }

Assert-Equal 0 (Get-CredentialExpiry $null) "sans jeton, expiration 0"
Assert-Equal "remote" (Select-FresherCredential 100 200) "distant plus frais"
Assert-Equal "local" (Select-FresherCredential 300 200) "local plus frais"
Assert-Equal "same" (Select-FresherCredential 200 200) "egalite"

$listing = @{ ".claude-credtest.json" = @{ Id = "c1"; Exp = 200 } }
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
Assert-Equal "jeton local illisible" $err "jeton local tenu par Claude Code : compte en echec"
Assert-Equal "tenu" (Read-AccountCredential $acc).claudeAiOauth.accessToken "jeton local tenu : jamais remplace"
$script:RemoteText = ((New-TestCred 300 "autre") | ConvertTo-Json -Depth 10 -Compress)
$err = ""; try { $null = Sync-AccountCredential $acc $fold $listing } catch { $err = $_.Exception.Message }
Assert-Equal "jeton du Drive invalide" $err "jeton du Drive d'une autre expiration : refuse"
$script:RemoteText = '{"claudeAiOauth":{"expiresAt":200}}'
$err = ""; try { $null = Sync-AccountCredential $acc $fold $listing } catch { $err = $_.Exception.Message }
Assert-Equal "jeton du Drive invalide" $err "jeton du Drive sans jeton d'acces : refuse"
$null = New-SandboxFile ".claude-credtest/.claude.json" '{"oauthAccount":{"emailAddress":"a@x.fr"}}'
$script:RemoteText = ((New-TestCred 200 "intrus") | ConvertTo-Json -Depth 10 -Compress)
$err = ""; try { $null = Sync-AccountCredential $acc $fold @{ ".claude-credtest.json" = @{ Id = "c1"; Exp = 200; Props = @{ exp = "200"; who = "b@y.fr" } } } } catch { $err = $_.Exception.Message }
Assert-Equal "jeton du Drive pour une autre adresse (b@y.fr)" $err "jeton d'une autre adresse : refuse"
Assert-Equal "tenu" (Read-AccountCredential $acc).claudeAiOauth.accessToken "jeton d'une autre adresse : jeton local garde"
$script:Sent.Clear()
Write-CredentialFile $credPath (New-TestCred 600 "moi")
$null = Sync-AccountCredential $acc $fold @{}
Assert-Equal "a@x.fr" $script:Sent[0].Props["who"] "adresse du compte envoyee avec le jeton"
Remove-Item -LiteralPath (Join-Path $script:Sandbox ".claude-credtest/.claude.json") -Force
$script:RemoteText = ((New-TestCred 200 "distant") | ConvertTo-Json -Depth 10 -Compress)
Write-CredentialFile $credPath (New-TestCred 100 "vieux")
function Get-DriveText { param([string]$Id) Write-CredentialFile $credPath (New-TestCred 900 "claude"); return $script:RemoteText }
$null = Sync-AccountCredential $acc $fold $listing
Assert-Equal "claude" (Read-AccountCredential $acc).claudeAiOauth.accessToken "jeton renouvele par Claude pendant le telechargement : garde"
function Get-DriveText { param([string]$Id) return $script:RemoteText }
$hold = [IO.File]::Open($script:CredLockPath, "OpenOrCreate", "ReadWrite", "None")
$script:CredLockWaitMs = 0
try { $err = ""; try { $null = Sync-AccountCredential $acc $fold $listing } catch { $err = $_.Exception.Message } } finally { $hold.Dispose(); $script:CredLockWaitMs = 15000 }
Assert-Equal "jetons en cours de synchro" $err "jetons synchronises sous verrou"

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

Remove-Item -LiteralPath $script:DriveConfigPath -Force -ErrorAction SilentlyContinue
function Get-DriveFolders { throw "Drive appele sans connexion" }
Assert-Null (Receive-DriveCredential $acc) "Drive non connecte : rien recu"
Send-DriveCredential $acc
Assert-True $true "Drive non connecte : rien envoye, aucune erreur"
Save-DriveConfig @{ refreshToken = "r" }
$fut = [DateTimeOffset]::UtcNow.AddHours(2).ToUnixTimeMilliseconds()
function Get-DriveFolders { return @{ Root = "R"; Files = "F"; Credentials = "C"; Presence = "P" } }
function Get-DriveListing { param([string]$FolderId) return @{ ".claude-credtest.json" = @{ Id = "c1"; Exp = $fut } } }
$script:RemoteText = ((New-TestCred $fut "frais") | ConvertTo-Json -Depth 10 -Compress)
Write-CredentialFile $credPath (New-TestCred 1000 "expire")
$got = Update-AccountToken $acc (New-TestCred 1000 "expire")
Assert-Equal "frais" $got.claudeAiOauth.accessToken "renouvellement : jeton valable d'un autre PC pris sans appel a Anthropic"
Assert-True (Test-CredentialUsable $got) "jeton pris encore valable"
function Get-DriveListing { param([string]$FolderId) if ($FolderId -eq "P") { return @{ "AUTRE-PC.json" = @{ Props = @{ ".claude-credtest" = ("" + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) } } } }; return @{} }
$script:Renewed = 0
function Get-OauthUserAgent { $script:Renewed++; throw "Anthropic appele" }
Write-CredentialFile $credPath (New-TestCred 1000 "expire")
try { $got = Update-AccountToken $acc (New-TestCred 1000 "expire") } finally { . (Join-Path $bin "claude-token-refresh.ps1") }
Assert-Null $got "compte ouvert sur un autre PC : jamais renouvele ici"
Assert-Equal 0 $script:Renewed "compte ouvert ailleurs : Anthropic pas appele"
function Get-DriveFolders { throw "Drive injoignable" }
Write-CredentialFile $credPath (New-TestCred 1000 "expire")
Assert-Null (Receive-DriveCredential $acc) "Drive en panne : rien recu, aucune erreur"
Remove-Item -LiteralPath $script:DriveConfigPath -Force
. (Join-Path $bin "claude-drive-creds.ps1")
$os = $script:OsName
$savedUser = $env:USER
$script:OsName = "MacOS"
$env:USER = "florent"
$script:Kc = @{}
$script:SecArgs = New-Object 'System.Collections.Generic.List[string]'
$script:SecLog = New-Object 'System.Collections.Generic.List[string]'
function Invoke-SecurityBatch {
  param([string[]]$Lines)
  foreach ($line in $Lines) {
    if ($line -notmatch '^add-generic-password -U -a "([^"]*)" -s "([^"]*)" -X "([0-9a-f]*)"$') { continue }
    $hex = $Matches[3]
    $b = New-Object byte[] ($hex.Length / 2)
    for ($i = 0; $i -lt $b.Length; $i++) { $b[$i] = [Convert]::ToByte($hex.Substring($i * 2, 2), 16) }
    $script:Kc[$Matches[1]] = [Text.Encoding]::UTF8.GetString($b)
    $script:SecLog.Add("add " + $Matches[1] + " " + $Matches[2])
  }
}
function security {
  $a = @($args)
  $global:LASTEXITCODE = 0
  $script:SecArgs.Add(($a -join " "))
  if ($a[0] -eq "find-generic-password") { $v = $script:Kc[$a[2]]; if ($null -eq $v) { $global:LASTEXITCODE = 44 } else { return $v } }
  elseif ($a[0] -eq "delete-generic-password") { $script:SecLog.Add("delete " + $a[2]); $script:Kc.Remove($a[2]) }
}
function Set-KcChunks {
  param([string]$Json)
  $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Json))
  $script:Kc["claude-code-user#0"] = $b64
  $script:Kc["claude-code-user#m"] = '{"n":1,"l":' + $b64.Length + '}'
}
try {
  Write-AccountCredential $acc (New-TestCred 900 "mac")
  $firstLog = $script:SecLog[0]
  $mac = Read-AccountCredential $acc
  Write-AccountCredential $acc (New-TestCred 901 ("x" * 7000))
  $back = Read-AccountCredential $acc
  $keys = @($script:Kc.Keys).Count
  $parts = [int]($script:Kc["claude-code-user#m"] | ConvertFrom-Json).n
  $simpleLeft = $script:Kc.ContainsKey("claude-code-user")
  $script:SecLog.Clear()
  Write-AccountCredential $acc (New-TestCred 902 "court")
  $order = @($script:SecLog)
  $after = Read-AccountCredential $acc
  $left = @($script:Kc.Keys).Count
  $script:Kc.Clear()
  $script:Kc["florent"] = ((New-TestCred 100 "ancien") | ConvertTo-Json -Depth 10 -Compress)
  Write-AccountCredential $acc (New-TestCred 903 "neuf")
  $userKeys = (@($script:Kc.Keys) | Sort-Object) -join ","
  $script:Kc.Clear()
  $script:Kc["claude-code-user"] = ((New-TestCred 950 "simple") | ConvertTo-Json -Depth 10 -Compress)
  Set-KcChunks ((New-TestCred 800 "morceaux") | ConvertTo-Json -Depth 10 -Compress)
  $best = Read-AccountCredential $acc
  Remove-KeychainCredential (Join-Path $script:Sandbox ".claude-credtest")
  $cleared = @($script:Kc.Keys).Count
} finally { $script:OsName = $os; $env:USER = $savedUser; Remove-Item Function:\security; . (Join-Path $bin "claude-keychain.ps1") }
Assert-Equal ("add claude-code-user " + (Get-KeychainService (Join-Path $script:Sandbox ".claude-credtest"))) $firstLog "trousseau : service du dossier du compte"
Assert-Equal "mac" $mac.claudeAiOauth.accessToken "trousseau : jeton ecrit puis relu"
Assert-Equal 0 @($script:SecArgs | Where-Object { $_.Contains("accessToken") -or $_.Contains("xxxxxxxx") }).Count "trousseau : jeton jamais passe en argument de commande"
Assert-Equal ("x" * 7000) $back.claudeAiOauth.accessToken "trousseau : jeton long relu entier"
Assert-Equal ($parts + 1) $keys "trousseau : jeton long en morceaux et un index, rien d'autre"
Assert-True (-not $simpleLeft) "trousseau : ancien jeton court retire"
Assert-True ($order[0] -like "add *") "trousseau : nouveau jeton ecrit avant de retirer l'ancien"
Assert-Equal "court" $after.claudeAiOauth.accessToken "trousseau : morceaux remplaces par un jeton court"
Assert-Equal 1 $left "trousseau : anciens morceaux retires"
Assert-Equal "florent" $userKeys "trousseau : jeton ecrit sous le nom de compte deja present"
Assert-Equal "simple" $best.claudeAiOauth.accessToken "trousseau : jeton le plus frais lu entre morceaux et element simple"
Assert-Equal 0 $cleared "trousseau : compte retire, tous ses elements effaces"
$script:OsName = $credOs
