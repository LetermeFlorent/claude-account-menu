. (Join-Path $bin "claude-menu-loop.ps1")
. (Join-Path $bin "claude-menu-startup.ps1")
. (Join-Path $bin "claude-menu-rename.ps1")
. (Join-Path $bin "claude-menu-remove.ps1")
. (Join-Path $bin "claude-menu-prefs.ps1")
. (Join-Path $bin "claude-menu-save.ps1")
. (Join-Path $bin "claude-cli.ps1")
. (Join-Path $bin "claude-web-server.ps1")
. (Join-Path $bin "claude-web-state.ps1")
. (Join-Path $bin "claude-web-lists.ps1")
. (Join-Path $bin "claude-web-actions.ps1")

$actMocked = @("Send-WebJson", "Stop-MenuLoader", "Start-MenuLoader", "Hide-Screen", "Invoke-UiWork", "Save-Accounts", "Restore-Accounts", "Get-ZipAccounts", "Assert-BackupVersion", "Request-DriveSync", "Set-DriveAuto", "Test-DriveConnected", "Read-CliPrefs", "Get-DownloadsDir", "Get-DrivePcName")
$actKept = @{}
foreach ($n in $actMocked) { $actKept[$n] = (Get-Item ("function:" + $n)).ScriptBlock }
$actSaved = @{
  Menu = $script:MenuState; Drive = $script:DriveJob; Check = $script:ClmCheck; Startup = $script:Startup; Ink = $script:Ink; InkTo = $script:InkTo; InkFrom = $script:InkFrom; InkTween = $script:InkTween
  Watch = $script:ThemeWatch; Motion = $script:MotionOn; Choice = $script:SyncChoicePath; Lock = $script:SyncChoiceLockPath; Wait = $script:SyncChoiceWaitMs
}
$actReg = $null
if (Test-Path -LiteralPath $script:RegistryPath) { $actReg = [IO.File]::ReadAllBytes($script:RegistryPath) }
$script:SyncChoicePath = Join-Path $script:Sandbox "web-choice.json"
$script:SyncChoiceLockPath = Join-Path $script:Sandbox "web-choice.lock"
$script:SyncChoiceWaitMs = 0
$actDl = Join-Path $script:Sandbox "web-act-dl"
New-Item -ItemType Directory -Path $actDl -Force | Out-Null
$actZip = Join-Path $actDl "claude-comptes-20261003-100000.zip"
[IO.File]::WriteAllText($actZip, "zip")
Add-BackupMark $actZip

function Send-WebJson { param($Conn, [int]$Code, $Data) $script:ActSent = @{ Code = $Code; Data = $Data } }
function Stop-MenuLoader { param([int]$TimeoutMs) $script:ActStops++ }
function Start-MenuLoader { param($State) }
function Hide-Screen {}
function Invoke-UiWork { param([string]$Title, [string]$Text, [scriptblock]$Work) $script:ActWork = $Title; return (& $Work) }
function Save-Accounts { param([string]$Tag, $Accs) $script:ActBackup = (@($Accs | ForEach-Object { $_.Label }) -join ","); return "C:\dl\claude-comptes.zip" }
function Restore-Accounts { param([string]$Zip, $Accs) $script:ActRestored = [IO.Path]::GetFileName($Zip) + ":" + (@($Accs | ForEach-Object { $_.Dir }) -join ","); return "restauration terminee" }
function Get-ZipAccounts { param([string]$Zip) return @([PSCustomObject]@{ Label = "perso"; Dir = ".claude" }, [PSCustomObject]@{ Label = "Pro"; Dir = ".claude-compte2" }) }
function Assert-BackupVersion { param([string]$Zip) }
function Request-DriveSync { param($Job) $script:ActSyncs++; return @("  synchro Drive lancee", $script:Ink.Dim) }
function Set-DriveAuto { param([bool]$On) $script:ActAuto = $On }
function Test-DriveConnected { return $true }
function Read-CliPrefs {
  $skill = New-PrefsItem "skills" "dessin" "dessin" "" $true $false
  $all = New-PrefsAll "skills" "tous les skills" @($skill)
  $pcs = New-PathMap
  $pcs["loin"] = New-PcContent
  $pcs["loin"].Os = $script:OsName
  $pcs["vieux"] = New-PcContent
  $cat = @{ Waiting = @(); PerPc = $true; Skills = [string[]]@("dessin"); Pcs = $pcs }
  return @{ Catalog = $cat; Choice = (Read-SyncChoice); Lines = @((New-PrefsHead "Skills"), $all, $skill) }
}
function Get-DrivePcName { return "ICI" }
function Get-DownloadsDir { return $actDl }

function Invoke-ActTest {
  param([hashtable]$ActArgs)
  $script:ActSent = $null
  $next = Invoke-WebAction @{ Conn = $null; Args = $ActArgs }
  return @{ Code = $script:ActSent.Code; Ok = $script:ActSent.Data.ok; Msg = $script:ActSent.Data.msg; Data = $script:ActSent.Data.data; Next = $next.Name; Arg = $next.Arg }
}

function Get-ActOrder { return (@(Get-Accounts) | ForEach-Object { $_.Label + "=" + $_.Dir }) -join "|" }

function Restore-ActFakes {
  foreach ($n in $actMocked) { Set-Item ("function:" + $n) $actKept[$n] }
  if ($null -ne $actReg) { [IO.File]::WriteAllBytes($script:RegistryPath, $actReg) } else { Remove-Item -LiteralPath $script:RegistryPath -Force -ErrorAction SilentlyContinue }
  Remove-Item -LiteralPath (Get-DisplayPath) -Force -ErrorAction SilentlyContinue
  $script:MenuState = $actSaved.Menu
  $script:DriveJob = $actSaved.Drive
  $script:ClmCheck = $actSaved.Check
  $script:Startup = $actSaved.Startup
  $script:Ink = $actSaved.Ink
  $script:InkTo = $actSaved.InkTo
  $script:InkFrom = $actSaved.InkFrom
  $script:InkTween = $actSaved.InkTween
  $script:ThemeWatch = $actSaved.Watch
  $script:MotionOn = $actSaved.Motion
  $script:SyncChoicePath = $actSaved.Choice
  $script:SyncChoiceLockPath = $actSaved.Lock
  $script:SyncChoiceWaitMs = $actSaved.Wait
}
