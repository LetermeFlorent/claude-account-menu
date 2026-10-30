. Import-ClmModule claude-lazy-load, claude-menu-clm-restart
$lazyDir = Join-Path $script:Sandbox "lazy-bin"
$null = New-Item -ItemType Directory -Path $lazyDir -Force
$null = New-SandboxFile "lazy-bin/lazy-part.ps1" @'
$script:LazyLoads++
if ([IO.File]::Exists((Join-Path $PSScriptRoot "bump"))) { [IO.File]::WriteAllText((Join-Path $PSScriptRoot "clm.version"), "v9") }
function Get-LazyPart { return "charge" }
'@
$lazySaved = @{ Dir = $script:ClmModuleDir; Groups = $script:ClmGroups; Stamp = $script:ClmGroupStamp; Once = $script:ClmOnce; Due = $script:ClmRestartDue; Updated = $script:ClmUpdated; Startup = $script:Startup; Job = $script:DriveJob; Reloaded = $script:ClmReloaded }

function Use-LazyGroup { return Import-ClmGroup lazy }

function Reset-LazyGroup {
  param([string]$Stamp)
  $script:LazyLoads = 0
  $script:ClmOnce = New-Object 'System.Collections.Generic.HashSet[string]'
  $script:ClmRestartDue = $false
  $script:ClmGroupStamp = "v1"
  [void]$script:ClmGroupsLoaded.Remove("lazy")
  Remove-Item -LiteralPath Function:\Get-LazyPart -ErrorAction Ignore
  $null = New-SandboxFile "lazy-bin/clm.version" $Stamp
}

function Get-LazyResult {
  param([string]$Used)
  return ($Used, $script:LazyLoads, [bool](Test-Path Function:\Get-LazyPart), $script:ClmRestartDue) -join "|"
}

try {
  $script:ClmModuleDir = $lazyDir
  $script:ClmGroups = @{ lazy = @("lazy-part") }
  $script:Startup = $null
  $script:DriveJob = $null

  Reset-LazyGroup "v1"
  $used = (Use-LazyGroup), (Use-LazyGroup) -join ","
  Assert-Equal "True,True|1|True|False" (Get-LazyResult $used) "chargement a la demande : charge au premier usage, une seule fois"
  Assert-Equal "charge" (Get-LazyPart) "chargement a la demande : fonctions visibles hors de la fonction qui charge"

  Reset-LazyGroup "v2"
  Assert-Equal "False|0|False|True" (Get-LazyResult (Use-LazyGroup)) "chargement a la demande, version changee : rien charge, redemarrage demande"
  Assert-Equal "restart" (Get-ClmRestartAction @{ Name = "none" }).Name "chargement a la demande, version changee : le menu redemarre"

  Reset-LazyGroup "v1"
  $flag = New-SandboxFile "lazy-bin/clm.installing" "1"
  Assert-Equal "False|0|False|True" (Get-LazyResult (Use-LazyGroup)) "chargement a la demande, installation en cours : rien charge"
  Remove-Item -LiteralPath $flag -Force

  Reset-LazyGroup "v1"
  $flag = New-SandboxFile "lazy-bin/bump" "1"
  Assert-Equal "False|1|True|True" (Get-LazyResult (Use-LazyGroup)) "chargement a la demande, version changee pendant le chargement : redemarrage demande"
  Assert-Equal "False" (Use-LazyGroup) "chargement a la demande, version changee pendant le chargement : pas marque charge"
  Remove-Item -LiteralPath $flag -Force

  Reset-LazyGroup "v2"
  $lazyReload = (Get-Item Function:\Invoke-ClmReload -ErrorAction Ignore)
  function Invoke-ClmReload { param([string]$Script, [object[]]$Argv) $script:LazyReloaded = $Script + " " + ($Argv -join " ") }
  $script:LazyReloaded = ""
  Import-ClmGroupOrReload @("lazy") "clm.ps1" @("-1")
  Assert-Equal "clm.ps1 -1|0" ($script:LazyReloaded + "|" + $script:LazyLoads) "lancement direct, version changee : clm relance, aucun compte ouvert"
  Reset-LazyGroup "v2"
  $script:LazyReloaded = ""
  $script:ClmReloaded = $true
  Import-ClmGroupOrReload @("lazy") "clm.ps1" @("-1")
  Assert-Equal "|1|True" ($script:LazyReloaded + "|" + $script:LazyLoads + "|" + [bool](Test-Path Function:\Get-LazyPart)) "lancement direct deja relance, version changee : charge sans seconde relance"
  if ($null -ne $lazyReload) { Set-Item -Path Function:script:Invoke-ClmReload -Value $lazyReload.ScriptBlock } else { Remove-Item -LiteralPath Function:\Invoke-ClmReload }
} finally {
  $script:ClmModuleDir = $lazySaved.Dir
  $script:ClmGroups = $lazySaved.Groups
  $script:ClmGroupStamp = $lazySaved.Stamp
  $script:ClmOnce = $lazySaved.Once
  $script:ClmRestartDue = $lazySaved.Due
  $script:ClmUpdated = $lazySaved.Updated
  $script:Startup = $lazySaved.Startup
  $script:DriveJob = $lazySaved.Job
  $script:ClmReloaded = $lazySaved.Reloaded
  [void]$script:ClmGroupsLoaded.Remove("lazy")
  Remove-Item -LiteralPath Function:\Get-LazyPart -ErrorAction Ignore
}

$lazyProbe = @'
param([string]$Bin, [string]$Out, [string]$Case)
$ProgressPreference = "SilentlyContinue"
$tk = $null; $er = $null
$menu = [Management.Automation.Language.Parser]::ParseFile((Join-Path $Bin "claude-menu.ps1"), [ref]$tk, [ref]$er)
$roots = foreach ($c in $menu.FindAll({ param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq "Import-ClmModule" }, $true)) {
  foreach ($e in @($c.CommandElements | Select-Object -Skip 1)) { if ($e -is [Management.Automation.Language.ArrayLiteralAst]) { foreach ($x in $e.Elements) { $x.Extent.Text } } else { $e.Extent.Text } }
}
$script:ClmOnce = New-Object 'System.Collections.Generic.HashSet[string]'
. (Join-Path $Bin "claude-import.ps1")
. Import-ClmModule $roots
if ($Case -eq "avec") { Save-DriveConfig @{ refreshToken = "r"; lastSync = 1 } }
$err = ""
try { Open-MenuSession $false $false; if ($Case -eq "avec") { Stop-DriveJob $script:DriveJob 0 } } catch { $err = "erreur " + $_.Exception.Message }
[IO.File]::WriteAllLines($Out, [string[]](@($err) + @($script:ClmOnce)))
'@
$lazyProbeFile = New-SandboxFile "lazy-probe.ps1" $lazyProbe
$lazyExe = (Get-Process -Id $PID).Path
$lazyGlue = @("claude-drive-cli", "claude-drive-job", "claude-drive-config")
foreach ($case in @("sans", "avec")) {
  $out = Join-Path $script:Sandbox ("lazy-start-" + $case + ".txt")
  $state = Join-Path $script:Sandbox ("lazy-state-" + $case)
  $savedProfile = $env:USERPROFILE; $savedHome = $env:HOME; $savedLocal = $env:LOCALAPPDATA
  $env:USERPROFILE = $state; $env:HOME = $state; $env:LOCALAPPDATA = Join-Path $state "AppData"
  try { & $lazyExe -NoProfile -ExecutionPolicy Bypass -File $lazyProbeFile -Bin $bin -Out $out -Case $case | Out-Null }
  finally { $env:USERPROFILE = $savedProfile; $env:HOME = $savedHome; $env:LOCALAPPDATA = $savedLocal }
  $lines = @()
  if (Test-Path -LiteralPath $out) { $lines = [IO.File]::ReadAllLines($out) }
  $late = @($lines | Where-Object { $_ -match "^claude-(drive-|web-|mcp-|sync)" -and $lazyGlue -notcontains $_ })
  if ($case -eq "sans") { Assert-Equal "|" (($lines | Select-Object -First 1) + "|" + ($late -join ",")) "demarrage sans Drive : aucun module drive, web, mcp ou sync charge"; continue }
  $missing = @($script:ClmGroups["drive"] | Where-Object { $lines -notcontains $_ })
  $other = @($late | Where-Object { $_ -match "^claude-web-" })
  Assert-Equal "||" (($lines | Select-Object -First 1) + "|" + ($missing -join ",") + "|" + ($other -join ",")) "demarrage avec Drive : modules drive charges a la demande, aucun module web"
}
