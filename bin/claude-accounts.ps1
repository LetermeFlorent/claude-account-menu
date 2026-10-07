. (Join-Path $PSScriptRoot "claude-platform.ps1")
. (Join-Path $PSScriptRoot "claude-credentials.ps1")
$script:HomeDir = Get-HomeDir
$script:RegistryPath = Join-Path $script:HomeDir ".claude-accounts.json"
$script:ClaudeExe = Find-ClaudeExe

function Get-ClaudeVersion {
  try { $v = "" + (& $script:ClaudeExe --version 2>$null) } catch { $v = "" }
  if ($v -match "(\d+\.\d+\.\d+)") { return $Matches[1] }
  return "1.0.0"
}
$script:SharedDirs = @("agents", "commands", "hooks", "rules", "skills")
$script:SharedFiles = @("ANTI-EMPREINTE.md", "CLAUDE.md", "settings.local.json", "statusline.json")

function Get-Accounts {
  if (Test-Path -LiteralPath $script:RegistryPath) {
    try {
      $data = Get-Content -LiteralPath $script:RegistryPath -Raw | ConvertFrom-Json
      return @($data | ForEach-Object { $_ })
    } catch {}
  }
  $list = @([PSCustomObject]@{ Label = "compte1"; Dir = ".claude" })
  foreach ($n in 2..9) {
    $d = ".claude-compte" + $n
    if (Test-Path -LiteralPath (Join-Path $script:HomeDir $d)) { $list += [PSCustomObject]@{ Label = "compte" + $n; Dir = $d } }
  }
  Save-Registry $list
  return $list
}

function Save-Registry {
  param($List)
  ConvertTo-Json -InputObject @($List) -Depth 3 | Set-Content -LiteralPath $script:RegistryPath -Encoding UTF8
}

function Get-AccountPath {
  param($Acc)
  return Join-Path $script:HomeDir $Acc.Dir
}

function Get-AccountConfigFile {
  param($Acc)
  if ($Acc.Dir -eq ".claude") { return Join-Path $script:HomeDir ".claude.json" }
  return Join-Path (Get-AccountPath $Acc) ".claude.json"
}

function Get-AccountEmail {
  param($Acc)
  try { $raw = Get-Content -LiteralPath (Get-AccountConfigFile $Acc) -Raw -ErrorAction Stop } catch { return "" }
  if ($raw -match '"oauthAccount"\s*:\s*\{[^}]*?"emailAddress"\s*:\s*"([^"]+)"') { return $Matches[1] }
  return ""
}

function Invoke-InAccountEnv {
  param($Acc, [scriptblock]$Action)
  $prev = $env:CLAUDE_CONFIG_DIR
  try {
    if ($Acc.Dir -eq ".claude") { Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue }
    else { $env:CLAUDE_CONFIG_DIR = Get-AccountPath $Acc }
    & $Action
  } finally {
    if ($null -eq $prev) { Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue } else { $env:CLAUDE_CONFIG_DIR = $prev }
  }
}

function Invoke-AsAccount {
  param($Acc, [object[]]$ArgList)
  Invoke-InAccountEnv $Acc { & $script:ClaudeExe @ArgList }
}

function Repair-SharedLinks {
  param($Acc, [switch]$Force)
  if ($Acc.Dir -eq ".claude") { return }
  $main = Join-Path $script:HomeDir ".claude"
  $dir = Get-AccountPath $Acc
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  foreach ($d in $script:SharedDirs) {
    $src = Join-Path $main $d; $dst = Join-Path $dir $d
    if ((Test-Path -LiteralPath $src) -and -not (Test-Path -LiteralPath $dst)) { New-Item -ItemType (Get-DirLinkType) -Path $dst -Target $src | Out-Null }
  }
  foreach ($f in $script:SharedFiles) {
    $src = Join-Path $main $f; $dst = Join-Path $dir $f
    if (-not (Test-Path -LiteralPath $src)) { continue }
    if ($Force -and (Test-Path -LiteralPath $dst)) { Remove-Item -LiteralPath $dst -Force }
    if (-not (Test-Path -LiteralPath $dst)) { New-Item -ItemType HardLink -Path $dst -Target $src | Out-Null }
  }
}

function New-AccountSlot {
  param([string]$Label)
  $list = @(Get-Accounts)
  $n = $list.Count + 1
  while (Test-Path -LiteralPath (Join-Path $script:HomeDir (".claude-compte" + $n))) { $n++ }
  if ([string]::IsNullOrWhiteSpace($Label)) { $Label = "compte" + $n }
  $acc = [PSCustomObject]@{ Label = $Label.Trim(); Dir = ".claude-compte" + $n }
  Repair-SharedLinks $acc
  $dir = Get-AccountPath $acc
  $settings = [IO.Path]::Combine($script:HomeDir, ".claude", "settings.json")
  if (Test-Path -LiteralPath $settings) { Copy-Item -LiteralPath $settings -Destination $dir }
  $cfg = [PSCustomObject]@{ hasCompletedOnboarding = $true; lastOnboardingVersion = (Get-ClaudeVersion) }
  $cfg | ConvertTo-Json | Set-Content -LiteralPath (Get-AccountConfigFile $acc) -Encoding UTF8
  Save-Registry ($list + $acc)
  return $acc
}

function Add-Account {
  Clear-Host
  Write-Host ""
  Write-Host "  Ajouter un compte Claude"
  Write-Host "  Le navigateur va s'ouvrir sur la page de connexion." -ForegroundColor DarkGray
  Write-Host "  Si claude.ai y est deja connecte sur un autre compte, copie le lien affiche" -ForegroundColor DarkGray
  Write-Host "  dans une fenetre privee, sinon c'est cet autre compte qui sera enregistre." -ForegroundColor DarkGray
  Write-Host ""
  $label = Read-Host "  Nom du compte (Entree pour le nom par defaut, q pour annuler)"
  if ($label -eq "q") { return "ajout annule" }
  $acc = New-AccountSlot $label
  Invoke-AsAccount $acc @("auth", "login")
  $mail = Get-AccountEmail $acc
  if ($mail -eq "") { return $acc.Label + " cree, mais non connecte : relance-le pour faire /login" }
  return $acc.Label + " ajoute : " + $mail
}
