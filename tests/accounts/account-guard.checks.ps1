$savedRegistry = $null
if (Test-Path -LiteralPath $script:RegistryPath) { $savedRegistry = [IO.File]::ReadAllText($script:RegistryPath) }
$savedVersion = ${function:Get-ClaudeVersion}
function Get-ClaudeVersion { return "9.9.9" }
$g1 = [PSCustomObject]@{ Label = "g1"; Dir = ".claude-guard1" }
$g2 = [PSCustomObject]@{ Label = "g2"; Dir = ".claude-guard2" }
$g3 = [PSCustomObject]@{ Label = "g3"; Dir = ".claude-guard3" }
Save-Registry @($g1, $g2, $g3)
New-Item -ItemType Directory -Path (Get-AccountPath $g1) -Force | Out-Null

Assert-True (Repair-Onboarding $g1) "garde, config absente creee"
$c1 = Read-JsonFile (Get-AccountConfigFile $g1)
Assert-Equal $true $c1["hasCompletedOnboarding"] "garde, accueil fait dans la config creee"
Assert-Equal "9.9.9" $c1["lastOnboardingVersion"] "garde, version d'accueil dans la config creee"

$cfg2 = New-SandboxFile ".claude-guard2/.claude.json" '{"hasCompletedOnboarding":false,"oauthAccount":{"emailAddress":"g@x"}}'
Assert-True (Repair-Onboarding $g2) "garde, accueil a refaire corrige"
$c2 = Read-JsonFile $cfg2
Assert-Equal $true $c2["hasCompletedOnboarding"] "garde, accueil passe a vrai"
Assert-Equal "g@x" $c2["oauthAccount"]["emailAddress"] "garde, compte garde"
Assert-Equal "9.9.9" $c2["lastOnboardingVersion"] "garde, version d'accueil ajoutee"
Assert-True (Test-Path -LiteralPath ($cfg2 + ".bak-sync")) "garde, sauvegarde avant ecriture"

$okText = '{"hasCompletedOnboarding":true,"lastOnboardingVersion":"1.2.3"}'
$cfg3 = New-SandboxFile ".claude-guard3/.claude.json" $okText
Assert-True (-not (Repair-Onboarding $g3)) "garde, accueil deja fait"
Assert-Equal $okText ([IO.File]::ReadAllText($cfg3)) "garde, config intacte quand tout va bien"
[IO.File]::WriteAllText($cfg3, '{"oauthAccount":{"emailAddress":"h@x"}}')
Assert-True (Repair-Onboarding $g3) "garde, accueil absent ajoute"
Assert-Equal $true (Read-JsonFile $cfg3)["hasCompletedOnboarding"] "garde, accueil absent passe a vrai"
Assert-Equal "h@x" (Read-JsonFile $cfg3)["oauthAccount"]["emailAddress"] "garde, compte garde quand l'accueil manque"
[IO.File]::WriteAllText($cfg3, "")
Assert-True (Repair-Onboarding $g3) "garde, config vide refaite"
Assert-Equal $true (Read-JsonFile $cfg3)["hasCompletedOnboarding"] "garde, accueil fait dans la config vide refaite"

$set1 = New-SandboxFile ".claude-guard1/settings.json" '{"model":"opus"}'
Assert-Equal "dark" (Find-KnownTheme $g1 @($g1, $g2, $g3)) "garde, theme sombre par defaut"
$null = New-SandboxFile ".claude-guard3/settings.json" '{"theme":"light"}'
Assert-True (Repair-Theme $g1 @($g1, $g2, $g3)) "garde, theme absent ajoute"
$s1 = Read-JsonFile $set1
Assert-Equal "light" $s1["theme"] "garde, theme repris d'un autre compte"
Assert-Equal "opus" $s1["model"] "garde, reglages gardes"
Assert-True (-not (Repair-Theme $g1 @($g1, $g2, $g3))) "garde, theme deja present"
Assert-True (-not (Repair-Theme $g2 @($g1, $g2, $g3))) "garde, pas de reglages, rien a faire"
Assert-True (-not (Test-Path -LiteralPath (Join-Path (Get-AccountPath $g2) "settings.json"))) "garde, reglages pas crees"

$bad = New-SandboxFile ".claude-guard2/settings.json" "{pas du json"
Repair-AccountConfig $g2 6>$null
Assert-Equal "{pas du json" ([IO.File]::ReadAllText($bad)) "garde, reglages illisibles laisses tels quels"
Remove-Item -LiteralPath $bad -Force
Repair-AccountConfig $g2
Assert-Equal $true (Read-JsonFile $cfg2)["hasCompletedOnboarding"] "garde complete, accueil fait"

Set-Item -Path function:Get-ClaudeVersion -Value $savedVersion
foreach ($a in @($g1, $g2, $g3)) { Remove-Item -LiteralPath (Get-AccountPath $a) -Recurse -Force -ErrorAction SilentlyContinue }
if ($null -ne $savedRegistry) { [IO.File]::WriteAllText($script:RegistryPath, $savedRegistry) } else { Remove-Item -LiteralPath $script:RegistryPath -Force }
