$addSaved = $null
if (Test-Path -LiteralPath $script:RegistryPath) { $addSaved = [IO.File]::ReadAllBytes($script:RegistryPath) }
$addFns = @{ r = ${function:Repair-SharedLinks}; v = ${function:Get-ClaudeVersion}; w = ${function:Write-TextFileAtomic} }
$script:AddWrites = @()
function Repair-SharedLinks { param($Acc, [switch]$Force) $null = New-Item -ItemType Directory -Path (Get-AccountPath $Acc) -Force }
function Get-ClaudeVersion { return "2.3.4" }
function Write-TextFileAtomic { param([string]$Path, [string]$Text, [switch]$Private, [switch]$Bom) $script:AddWrites += $Path; & $addFns.w @PSBoundParameters }
$null = New-Item -ItemType Directory -Path (Join-Path $script:HomeDir ".claude") -Force
$addSlot = New-AccountSlot "atomique"
${function:Repair-SharedLinks} = $addFns.r
${function:Get-ClaudeVersion} = $addFns.v
${function:Write-TextFileAtomic} = $addFns.w
$addCfg = Get-AccountConfigFile $addSlot
Assert-True ($script:AddWrites -contains $addCfg) "ajout : config ecrite par l'ecrivain atomique"
$addBytes = [IO.File]::ReadAllBytes($addCfg)
Assert-True (-not ($addBytes.Length -ge 3 -and $addBytes[0] -eq 0xEF -and $addBytes[1] -eq 0xBB -and $addBytes[2] -eq 0xBF)) "ajout : config en UTF-8 sans BOM"
$addJson = Read-JsonFile $addCfg
Assert-Equal $true $addJson["hasCompletedOnboarding"] "ajout : accueil fait dans la config"
Assert-Equal "2.3.4" $addJson["lastOnboardingVersion"] "ajout : version dans la config"
$addTmp = @(Get-ChildItem -LiteralPath (Split-Path $addCfg) -Filter "*.tmp" -Force)
Assert-Equal 0 $addTmp.Count "ajout : aucun fichier temporaire laisse"
Remove-Item -LiteralPath (Join-Path $script:HomeDir $addSlot.Dir) -Recurse -Force -ErrorAction SilentlyContinue
if ($null -ne $addSaved) { [IO.File]::WriteAllBytes($script:RegistryPath, $addSaved) } else { Remove-Item -LiteralPath $script:RegistryPath -Force }
