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

$os = $script:OsName
$script:OsName = "MacOS"
$script:SecCalls = New-Object 'System.Collections.Generic.List[string]'
function security { $script:SecCalls.Add(($args -join " ")); $global:LASTEXITCODE = 0; if ($args[0] -eq "find-generic-password") { $global:LASTEXITCODE = 44 } }
try { Write-AccountCredential $acc (New-TestCred 900 "mac") } finally { $script:OsName = $os; Remove-Item Function:\security }
$add = @($script:SecCalls | Where-Object { $_ -like "add-generic-password*" })
Assert-Equal 1 $add.Count "trousseau : une ecriture"
Assert-True ($add[0].Contains("-U -a claude-code-user -s " + (Get-KeychainService (Join-Path $script:Sandbox ".claude-credtest")))) "trousseau : service du dossier du compte"
Assert-True ($add[0].Contains('"accessToken":"mac"')) "trousseau : jeton ecrit"
Assert-True (@($script:SecCalls | Where-Object { $_ -like "delete-generic-password*" }).Count -gt 0) "trousseau : ancien jeton retire avant"

$now = 1000000
$pres = @{
  "MAC.json" = @{ Props = @{ ".claude" = ("" + ($now - 100)); ".claude-compte2" = ("" + ($now - 13 * 3600)); ".claude-compte4" = "0" } }
  "PC.json" = @{ Props = @{ ".claude-compte3" = ("" + $now) } }
}
$away = Get-AwayMap $pres "PC" $now
Assert-Equal 1 $away.Count "presence : seulement les comptes ouverts ailleurs depuis moins de 12 h"
Assert-Equal "MAC" $away[".claude"] "presence : nom de l'autre PC"

$script:Props = $null
function Get-DriveFolders { return @{ Root = "R"; Files = "F"; Credentials = "C"; Presence = "P" } }
function Get-DriveListing { param([string]$FolderId) return @{ ((Get-DrivePcName) + ".json") = @{ Id = "own" } } }
function Set-DriveProps { param([string]$Id, $Props) $script:Props = @($Id, $Props) }
Set-DrivePresence $acc $true
Assert-Equal "own" $script:Props[0] "presence : fichier du PC mis a jour"
Assert-True ([long]$script:Props[1][".claude-credtest"] -gt 1700000000) "presence : heure d'ouverture"
Set-DrivePresence $acc $false
Assert-Equal "0" $script:Props[1][".claude-credtest"] "presence : compte ferme"
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
function Get-DriveFolders { throw "Drive injoignable" }
Write-CredentialFile $credPath (New-TestCred 1000 "expire")
Assert-Null (Receive-DriveCredential $acc) "Drive en panne : rien recu, aucune erreur"
Remove-Item -LiteralPath $script:DriveConfigPath -Force
. (Join-Path $bin "claude-drive-creds.ps1")
$os = $script:OsName
$script:OsName = "MacOS"
$script:Kc = @{}
function security { $a = @($args); $global:LASTEXITCODE = 0; if ($a[0] -eq "add-generic-password") { $script:Kc[$a[3]] = $a[7] } elseif ($a[0] -eq "find-generic-password") { $v = $script:Kc[$a[2]]; if ($null -eq $v) { $global:LASTEXITCODE = 44 } else { return $v } } elseif ($a[0] -eq "delete-generic-password") { $script:Kc.Remove($a[2]) } }
$big = New-TestCred 900 ("x" * 7000)
try {
  Write-AccountCredential $acc $big
  $back = Read-AccountCredential $acc
  $small = @($script:Kc.Keys).Count
  Write-AccountCredential $acc (New-TestCred 901 "court")
  $after = Read-AccountCredential $acc
} finally { $script:OsName = $os; Remove-Item Function:\security }
Assert-Equal 5 $small "trousseau : jeton long decoupe en 4 morceaux et un index"
Assert-Equal ("x" * 7000) $back.claudeAiOauth.accessToken "trousseau : jeton long relu entier"
Assert-Equal "court" $after.claudeAiOauth.accessToken "trousseau : morceaux remplaces par un jeton court"
Assert-Equal 1 @($script:Kc.Keys).Count "trousseau : anciens morceaux retires"
