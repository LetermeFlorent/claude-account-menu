$scOs = $script:OsName
if ($scOs -eq "MacOS") { $script:OsName = "Linux" }
$acc = [PSCustomObject]@{ Label = "sc"; Dir = ".claude-sealcred" }
$scPath = Join-Path $script:Sandbox ".claude-sealcred/.credentials.json"
$null = New-SandboxFile ".claude-sealcred/.claude.json" '{"oauthAccount":{"emailAddress":"a@x.fr"}}'
$scFold = @{ Root = "R"; Files = "F"; Credentials = "C"; Presence = "P" }
$script:Sent = New-Object 'System.Collections.Generic.List[object]'
$script:RemoteText = ""
. (Join-Path (Split-Path -Parent $PSScriptRoot) "fake-creds.ps1")
$scOther = New-SyncKeys ([byte[]](100..131)) ([byte[]](1..16)) 600000
$scName = ".claude-sealcred.json"
$scListing = @{ $scName = @{ Id = "c1"; Exp = 900; Props = @{ exp = "900"; who = "a@x.fr" } } }
$scRemote = '{"claudeAiOauth":{"accessToken":"distant","refreshToken":"r","expiresAt":900,"scopes":["user:inference"]}}'

function Get-DriveBytes { param([string]$Id) return ,$script:ScBytes }

function Test-ScRefused {
  param([byte[]]$Bytes, [string]$Name)
  $script:ScBytes = $Bytes
  Write-CredentialFile $scPath ('{"claudeAiOauth":{"accessToken":"tenu","refreshToken":"r","expiresAt":100,"scopes":["user:inference"]}}' | ConvertFrom-Json)
  $err = $null
  try { $null = Sync-AccountCredential $acc $scFold $scListing } catch { $err = $_ }
  Assert-True (Test-SealRefusal $err) ("jeton du Drive " + $Name + " : refuse")
  Assert-Equal "tenu" (Read-AccountCredential $acc).claudeAiOauth.accessToken ("jeton du Drive " + $Name + " : jeton local garde")
}

$scPlain = [Text.Encoding]::UTF8.GetBytes($scRemote)
Test-ScRefused $scPlain "en clair"
Test-ScRefused (Protect-SyncBytes $script:CredTestKeys "credentials/.claude-autre.json" $scPlain) "d'un autre compte"
Test-ScRefused (Protect-SyncBytes $scOther ("credentials/" + $scName) $scPlain) "d'une autre phrase"
$scGood = Protect-SyncBytes $script:CredTestKeys ("credentials/" + $scName) $scPlain
$scBad = [byte[]]$scGood.Clone()
$scBad[10] = $scBad[10] -bxor 1
Test-ScRefused $scBad "modifie"
$script:ScBytes = $scGood
Assert-Equal "remote" (Sync-AccountCredential $acc $scFold $scListing) "jeton du Drive chiffre : pris"
Assert-Equal "distant" (Read-AccountCredential $acc).claudeAiOauth.accessToken "jeton du Drive chiffre : ecrit ici"

Write-CredentialFile $scPath ('{"claudeAiOauth":{"accessToken":"secret-local","refreshToken":"secret-refresh","expiresAt":5000,"scopes":["user:inference"]}}' | ConvertFrom-Json)
Assert-Equal "local" (Sync-AccountCredential $acc $scFold $scListing) "jeton local plus frais envoye"
$scSent = [Text.Encoding]::UTF8.GetString($script:Sent[0].Bytes)
Assert-True (-not $scSent.Contains("secret-local") -and -not $scSent.Contains("secret-refresh")) "jeton envoye chiffre, jamais en clair"
Assert-Equal "secret-local" ($script:Sent[0].Text | ConvertFrom-Json).claudeAiOauth.accessToken "jeton envoye relu avec la phrase"
Assert-True (-not (($script:Sent[0].Props.Values | ForEach-Object { [string]$_ }) -join "|").Contains("secret")) "aucun jeton dans les proprietes du Drive"

$script:Sent.Clear()
Remove-SyncKeys
$err = ""
try { $null = Sync-AccountCredential $acc $scFold $scListing } catch { $err = $_.Exception.Message }
Assert-Equal $script:SyncKeyMissing $err "sans phrase : jetons non synchronises"
Assert-Equal 0 $script:Sent.Count "sans phrase : aucun jeton envoye"
$script:OsName = $scOs
Remove-Item -LiteralPath (Join-Path $script:Sandbox ".claude-sealcred") -Recurse -Force
