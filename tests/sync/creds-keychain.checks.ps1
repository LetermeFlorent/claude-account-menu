Remove-Item -LiteralPath $script:DriveConfigPath -Force -ErrorAction SilentlyContinue
function Get-DriveFolders { throw "Drive appele sans connexion" }
Assert-Null (Receive-DriveCredential $acc) "Drive non connecte : rien recu"
Send-DriveCredential $acc
Assert-True $true "Drive non connecte : rien envoye, aucune erreur"
Save-DriveConfig @{ refreshToken = "r" }
$fut = [DateTimeOffset]::UtcNow.AddHours(2).ToUnixTimeMilliseconds()
function Get-DriveFolders { return @{ Root = "R"; Files = "F"; Credentials = "C"; Presence = "P" } }
function Get-DriveListing { param([string]$FolderId) return @{ ".claude-credtest.json" = @{ Id = "c1"; Exp = $fut; Props = @{ who = "a@x.fr" } } } }
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
Remove-Item -LiteralPath (Join-Path $script:Sandbox ".claude-credtest/.claude.json") -Force; Remove-SyncKeys
