$esc = [string][char]27
Assert-Equal "ab" (ConvertTo-AccountLabel ("a" + [char]9 + "b" + [char]0 + [char]127)) "nom : caracteres de controle retires"
Assert-Equal ("x" + "[2Jy") (ConvertTo-AccountLabel ("x" + $esc + "[2Jy")) "nom : debut de sequence d'echappement neutralise"
Assert-Equal "pro" (ConvertTo-AccountLabel "  pro  ") "nom : espaces autour retires"
Assert-Equal 40 (ConvertTo-AccountLabel ("n" * 60)).Length "nom : coupe a 40 caracteres"
Assert-Equal "" (ConvertTo-AccountLabel ($esc + [char]9)) "nom : que du controle, vide"
Assert-Equal "" (ConvertTo-AccountLabel $null) "nom : absent, vide"

. (Join-Path $bin "claude-menu-rename.ps1")
$labelSaved = $null
if (Test-Path -LiteralPath $script:RegistryPath) { $labelSaved = [IO.File]::ReadAllBytes($script:RegistryPath) }
Save-Registry @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" }, [PSCustomObject]@{ Label = "second"; Dir = ".claude-compte2" })
$accs = @(Get-Accounts)
$null = Rename-Account $accs[1] ("bon" + $esc + "[31m" + [char]7 + ("z" * 60))
$stored = (@(Get-Accounts))[1].Label
Assert-True ($stored -notmatch '[\x00-\x1F\x7F]') "renommage : aucun caractere de controle enregistre"
Assert-Equal 40 $stored.Length "renommage : nom coupe a 40 caracteres"
Assert-True (-not ([IO.File]::ReadAllText($script:RegistryPath).Contains("\u001b"))) "renommage : registre sans echappement"
$labelErr = $null
try { $null = Rename-Account (@(Get-Accounts))[1] ($esc + [char]9) } catch { $labelErr = $_.Exception.Message }
Assert-Equal "nom vide" $labelErr "renommage : nom fait que de controle refuse"

$slotFns = @{ r = ${function:Repair-SharedLinks}; v = ${function:Get-ClaudeVersion} }
function Repair-SharedLinks { param($Acc, [switch]$Force) $null = New-Item -ItemType Directory -Path (Get-AccountPath $Acc) -Force }
function Get-ClaudeVersion { return "1.0.0" }
$null = New-Item -ItemType Directory -Path (Join-Path $script:HomeDir ".claude") -Force
$slot = New-AccountSlot ("ajout" + $esc + "[0m" + [char]10 + ("q" * 60))
${function:Repair-SharedLinks} = $slotFns.r
${function:Get-ClaudeVersion} = $slotFns.v
Assert-True ($slot.Label -notmatch '[\x00-\x1F\x7F]') "ajout : aucun caractere de controle dans le nom"
Assert-Equal 40 $slot.Label.Length "ajout : nom coupe a 40 caracteres"
Remove-Item -LiteralPath (Join-Path $script:HomeDir $slot.Dir) -Recurse -Force -ErrorAction SilentlyContinue

. (Join-Path $bin "claude-menu-archive.ps1")
Initialize-Tar
$zipSrc = Join-Path $script:Sandbox "etiquette-archive"
$null = New-Item -ItemType Directory -Path (Join-Path $zipSrc ".claude-compte3") -Force
[IO.File]::WriteAllText((Join-Path $zipSrc ".claude-compte3\x.txt"), "x")
[IO.File]::WriteAllText((Join-Path $zipSrc ".claude-accounts.json"), ('[{ "Label": "evil\u001b[2J\u0007' + ("w" * 60) + '", "Dir": ".claude-compte3" }]'))
$zipFile = Join-Path $script:Sandbox ("etiquette" + (Get-ArchiveExtension $script:TarFlavor))
& $script:Tar -a -c -f $zipFile -C $zipSrc ".claude-accounts.json" ".claude-compte3"
$zipAccs = @(Get-ZipAccounts $zipFile)
Assert-Equal 1 $zipAccs.Count "archive : un compte relu"
Assert-True ($zipAccs[0].Label -notmatch '[\x00-\x1F\x7F]') "archive : nom lu sans caractere de controle"
Assert-Equal 40 $zipAccs[0].Label.Length "archive : nom lu coupe a 40 caracteres"
Remove-Item -LiteralPath $zipSrc, $zipFile -Recurse -Force

if ($null -ne $labelSaved) { [IO.File]::WriteAllBytes($script:RegistryPath, $labelSaved) } else { Remove-Item -LiteralPath $script:RegistryPath -Force }
