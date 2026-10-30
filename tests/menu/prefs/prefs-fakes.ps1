. (Join-Path $bin "menu/manage/claude-menu-prefs.ps1")

$prefsPaths = @($script:SyncCatalogPath, $script:SyncChoicePath, $script:SyncChoiceLockPath, $script:SyncChoiceWaitMs, $script:SkillsRoot, $script:UiRows)
$script:SyncCatalogPath = Join-Path $script:Sandbox "prefs-catalog.json"
$script:SyncChoicePath = Join-Path $script:Sandbox "prefs-choice.json"
$script:SyncChoiceLockPath = Join-Path $script:Sandbox "prefs-choice.lock"
$script:SyncChoiceWaitMs = 0
$script:SkillsRoot = "prefs-test/skills"
$prefsMocked = @("Show-UiRows", "Update-UiTick", "Test-DriveConnected", "Request-DriveSync", "Get-Accounts", "Get-DrivePcName")
$prefsKept = @{}
foreach ($n in $prefsMocked) { $prefsKept[$n] = (Get-Item ("function:" + $n)).ScriptBlock }

function Get-PrefsText {
  param($Lines)
  return (@($Lines | ForEach-Object { if ($_.Head) { "[" + $_.Label + "]" } else { $_.Label + ":" + [int]$_.On + [int]$_.Erasing } }) -join " ")
}

function Invoke-PrefsKeys {
  param([object[]]$Keys)
  $script:UiKeys.Clear()
  foreach ($k in $Keys) {
    $c = [char]0
    if ($k -is [string]) { $c = [char]$k; $k = [ConsoleKey]::D2 }
    if ($k -eq [ConsoleKey]::Spacebar) { $c = " " }
    $script:UiKeys.Enqueue((New-Object System.ConsoleKeyInfo $c, $k, $false, $false, $false))
  }
  return Show-PrefsMenu
}

function Show-UiRows { param($Rows, [double]$Now, $RowFades = $null) $script:PrefsShown = $Rows; $script:PrefsSeen += [string]($Rows | ForEach-Object { $_ | ForEach-Object { $_[0] } }) }
function Update-UiTick { param([double]$Now, [bool]$Busy) return $false }
function Test-DriveConnected { return $script:PrefsDrive }
function Request-DriveSync { param($Job) $script:PrefsSyncs++ }
function Get-Accounts { return @([PSCustomObject]@{ Label = "p"; Dir = ".claude-prefs" }) }
function Get-DrivePcName { return "MOI" }
function Get-PrefsShown { return [string]($script:PrefsShown | ForEach-Object { $_ | ForEach-Object { $_[0] } }) }

function New-PrefsFixture {
  $cat = New-SyncCatalog
  $cat.Skills = [string[]]@("alpha")
  $cat.Pcs["A"] = New-PcContent
  $cat.Pcs["A"].Mcp["|loin"] = @{ At = 5; Deleted = $false; Os = "Autre"; Def = "{}" }
  $cat.Pcs["A"].Mcp["|ici"] = @{ At = 5; Deleted = $false; Os = $script:OsName; Def = "{}" }
  $cat.Pcs["A"].Mcp["|parti"] = @{ At = 5; Deleted = $true; Os = $script:OsName; Def = "" }
  $cat.Pcs["A"].Mcp["Documents/p|outil"] = @{ At = 5; Deleted = $false; Os = $script:OsName; Def = "{}" }
  $cat.Parked["blender"] = "{}"
  $null = New-SandboxFile "prefs-test/skills/beta/SKILL.md" "b"
  return $cat
}

function Restore-PrefsFakes {
  foreach ($n in $prefsMocked) { Set-Item -Path ("function:" + $n) -Value $prefsKept[$n] }
  $script:UiKeys.Clear()
  Remove-Item -LiteralPath (Join-Path $script:Sandbox ".claude-prefs"), (Join-Path $script:Sandbox "prefs-test"), $script:SyncCatalogPath, $script:SyncChoicePath, $script:SyncChoiceLockPath -Recurse -Force -ErrorAction SilentlyContinue
  $script:SyncCatalogPath, $script:SyncChoicePath, $script:SyncChoiceLockPath, $script:SyncChoiceWaitMs, $script:SkillsRoot, $script:UiRows = $prefsPaths
}
