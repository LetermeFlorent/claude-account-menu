$dupSaved = $null
if (Test-Path -LiteralPath $script:RegistryPath) { $dupSaved = [IO.File]::ReadAllBytes($script:RegistryPath) }
$dupA = [PSCustomObject]@{ Label = "dupa"; Dir = ".claude-dupa" }
$dupB = [PSCustomObject]@{ Label = "dupb"; Dir = ".claude-dupb" }
$dupC = [PSCustomObject]@{ Label = "dupc"; Dir = ".claude-dupc" }
function Set-DupEmail {
  param($Acc, [string]$Mail)
  $d = Get-AccountPath $Acc
  $null = New-Item -ItemType Directory -Path $d -Force
  $cfg = [ordered]@{ hasCompletedOnboarding = $true }
  if ($Mail -ne "") { $cfg.oauthAccount = [ordered]@{ emailAddress = $Mail } }
  [IO.File]::WriteAllText((Get-AccountConfigFile $Acc), (ConvertTo-JsonText $cfg))
}
Set-DupEmail $dupA "Same@Mail.fr"
Set-DupEmail $dupB "same@mail.fr"
Set-DupEmail $dupC ""
Save-Registry @($dupA, $dupB, $dupC)
Assert-True (Test-DuplicateAccountEmail $dupA) "doublon : meme adresse sans tenir compte de la casse"
Assert-True (-not (Test-DuplicateAccountEmail $dupC)) "doublon : adresse vide jamais en double"
Set-DupEmail $dupB "other@mail.fr"
Assert-True (-not (Test-DuplicateAccountEmail $dupA)) "doublon : adresses differentes"

[IO.File]::WriteAllText((Join-Path (Get-AccountPath $dupA) ".credentials.json"), '{"claudeAiOauth":{"accessToken":"x"}}')
$dupSeen = Invoke-InAccountEnv $dupA { $env:DISABLE_LOGIN_COMMAND }
Assert-Equal "1" $dupSeen "connexion : /login cache pour un compte connecte"
Assert-Null $env:DISABLE_LOGIN_COMMAND "connexion : variable retiree apres la session"
$env:CLM_ALLOW_LOGIN = "1"
$dupSeen = Invoke-InAccountEnv $dupA { $env:DISABLE_LOGIN_COMMAND }
Remove-Item Env:CLM_ALLOW_LOGIN
Assert-Null $dupSeen "connexion : CLM_ALLOW_LOGIN=1 laisse /login"
$dupSeen = Invoke-InAccountEnv $dupB { $env:DISABLE_LOGIN_COMMAND }
Assert-Null $dupSeen "connexion : /login laisse sans identifiants"

Clear-AccountLogin $dupA
Assert-True (-not (Test-Path -LiteralPath (Join-Path (Get-AccountPath $dupA) ".credentials.json"))) "effacement : identifiants supprimes"
Assert-Equal "" (Get-AccountEmail $dupA) "effacement : adresse retiree de la config"
Assert-True ((Read-JsonFile (Get-AccountConfigFile $dupA))["hasCompletedOnboarding"]) "effacement : le reste de la config garde"

Set-DupEmail $dupA "same@mail.fr"
$dupFns = @{ r = ${function:Repair-SharedLinks}; v = ${function:Get-ClaudeVersion}; i = ${function:Invoke-AsAccount} }
function Repair-SharedLinks { param($Acc, [switch]$Force) $null = New-Item -ItemType Directory -Path (Get-AccountPath $Acc) -Force }
function Get-ClaudeVersion { return "2.3.4" }
function Invoke-AsAccount { param($Acc, [object[]]$ArgList) $script:DupNew = $Acc; Set-DupEmail $Acc "SAME@mail.fr" }
Assert-Throws { Connect-NewAccount "dupnew" } "SAME@mail.fr" "ajout : adresse deja prise refusee"
${function:Repair-SharedLinks} = $dupFns.r
${function:Get-ClaudeVersion} = $dupFns.v
${function:Invoke-AsAccount} = $dupFns.i
Assert-True (@(Get-Accounts | Where-Object { $_.Dir -eq $script:DupNew.Dir }).Count -eq 0) "ajout : compte en double retire de la liste"
Assert-True (-not (Test-Path -LiteralPath (Get-AccountPath $script:DupNew))) "ajout : dossier du compte en double supprime"
Assert-Equal 3 @(Get-Accounts).Count "ajout : les autres comptes restent"

$dupTokens = $null
$dupErrors = $null
$dupAst = [Management.Automation.Language.Parser]::ParseFile((Join-Path $bin "claude-menu.ps1"), [ref]$dupTokens, [ref]$dupErrors)
$dupStart = $dupAst.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq "Start-Account" }, $true)
Assert-True ($dupStart.Extent.Text -match "(?s)Invoke-AsAccount.*Test-DuplicateAccountEmail.*Clear-AccountLogin") "session : connexion en double effacee apres la session"

foreach ($a in @($dupA, $dupB, $dupC)) { Remove-Item -LiteralPath (Get-AccountPath $a) -Recurse -Force -ErrorAction SilentlyContinue }
if ($null -ne $dupSaved) { [IO.File]::WriteAllBytes($script:RegistryPath, $dupSaved) } else { Remove-Item -LiteralPath $script:RegistryPath -Force }
