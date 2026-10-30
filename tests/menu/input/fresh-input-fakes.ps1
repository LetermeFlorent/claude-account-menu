$script:FakeNow = 1000.0
$script:FakeOrigin = 0.0
$script:TimelineEvents = New-Object 'System.Collections.Generic.List[object]'
$script:TimelineLog = New-Object 'System.Collections.Generic.List[string]'
$script:TimelineAccounts = 1
$script:TimelineGuardAt = 0.0
$script:TimelineVars = @{}
$script:TimelineVarNames = @("MenuState", "Startup", "DriveJob", "ClmCheck", "MenuRestart", "MenuOffline", "ClmUpdated", "UiQuit", "UiOn", "WebOpen", "InputGate")
$script:TimelineMocks = [ordered]@{
  "Get-NowMs" = "Get-TimelineNow"; "Read-UiInput" = "Read-TimelineInput"; "Test-UiInputPending" = "Test-TimelinePending"
  "Show-Menu" = "Show-TimelineMenu"; "Get-Accounts" = "Get-TimelineAccounts"; "Enter-UiScreen" = "Enter-TimelineScreen"
  "Exit-UiScreen" = "Exit-TimelineScreen"; "Hide-Screen" = "Invoke-TimelineNothing"; "Start-MenuLoader" = "Invoke-TimelineNothing"
  "Start-DriveJob" = "Invoke-TimelineNothing"; "Update-UiTick" = "Get-TimelineFalse"; "Test-DriveAuto" = "Get-TimelineFalse"
  "Test-DriveConnected" = "Get-TimelineFalse"; "Test-SyncKeyStored" = "Get-TimelineFalse"; "Get-DriveLastSync" = "Get-TimelineFalse"
  "New-ClmCheck" = "New-TimelineClmCheck"; "Get-HeldKeys" = "Get-TimelineHeld"
}
function Get-TimelineNow { return [double]$script:FakeNow }
function Get-TimelineFalse { return $false }
function Get-TimelineHeld { return @($script:TimelineHeld) }
function Invoke-TimelineNothing { }
function Enter-TimelineScreen { $script:UiOn = $true }
function Exit-TimelineScreen { $script:UiOn = $false }
function New-TimelineClmCheck { return @{ Loader = $null; NextAt = $null; Installed = $null; Latest = $null } }
function Test-TimelineDue { return ($script:TimelineEvents.Count -gt 0 -and $script:TimelineEvents[0].At -le $script:FakeNow) }
function Test-TimelineGuard { return ($script:FakeNow - $script:FakeOrigin -ge 60000 -and $script:FakeNow -ge $script:TimelineGuardAt) }
function Test-TimelinePending { return ($script:UiKeys.Count -gt 0 -or (Test-TimelineDue) -or (Test-TimelineGuard)) }
function Step-FakeClock {
  param([double]$Seconds = 0, [double]$Milliseconds = 0)
  $script:FakeNow = $script:FakeNow + $Milliseconds + 1000 * $Seconds
  if ($script:FakeNow - $script:FakeOrigin -gt 120000) { throw "horloge simulee emballee" }
}
function Get-TimelineAccounts {
  $labels = @("a", "b", "c", "d", "e")[0..($script:TimelineAccounts - 1)]
  return @(foreach ($l in $labels) { [PSCustomObject]@{ Label = $l; Dir = (".claude-" + $l) } })
}
function Show-TimelineMenu {
  param($State, [double]$Now)
  $script:TimelineLog.Add("draw")
  $State.Hit = @{ Start = 4; Per = 5; Top = 0; Last = $State.Entries.Count }
  $State.Dirty = $false
}
function New-TimelineKey {
  param([string]$Name)
  $keys = @{ Enter = @(13, "Enter"); Escape = @(27, "Escape"); Digit1 = @(49, "D1"); Down = @(0, "DownArrow"); Up = @(0, "UpArrow"); CtrlC = @(3, "C") }
  $spec = $keys[$Name]
  return New-Object System.ConsoleKeyInfo ([char]$spec[0]), ([ConsoleKey]($spec[1])), $false, $false, ($Name -eq "CtrlC")
}
function ConvertTo-TimelineEvent {
  param([string]$Name)
  if ($Name -eq "click" -or $Name -eq "double") { return @{ Mouse = $Name; X = 5; Y = 4 } }
  if ($Name.StartsWith("up:")) { return @{ KeyUp = [int]$Name.Substring(3) } }
  return New-TimelineKey $Name
}
function Add-TimelineEvents {
  param([object[]]$Specs)
  foreach ($s in $Specs) {
    $at = $script:FakeOrigin + [double]$s[0]
    $pos = $script:TimelineEvents.Count
    while ($pos -gt 0 -and $script:TimelineEvents[$pos - 1].At -gt $at) { $pos-- }
    $script:TimelineEvents.Insert($pos, @{ At = $at; Ev = (ConvertTo-TimelineEvent ([string]$s[1])) })
  }
}

function Read-TimelineInput {
  if (Test-TimelineDue) {
    $ev = $script:TimelineEvents[0].Ev
    $script:TimelineEvents.RemoveAt(0)
    $script:TimelineLog.Add("read")
    return $ev
  }
  if (-not (Test-TimelineGuard)) { return $null }
  $script:TimelineGuardAt = $script:FakeNow + 1000
  $script:TimelineLog.Add("guard")
  return New-TimelineKey "Escape"
}

function Set-TimelineFunction {
  param([string]$Name, [scriptblock]$Body)
  if (-not $script:TimelineKept.ContainsKey($Name)) {
    $f = Get-Item ("function:" + $Name) -ErrorAction SilentlyContinue
    $script:TimelineKept[$Name] = $null
    if ($f) { $script:TimelineKept[$Name] = $f.ScriptBlock }
  }
  Set-Item -Path ("function:script:" + $Name) -Value $Body
}

function Install-TimelineFakes {
  $script:TimelineKept = @{}
  foreach ($n in $script:TimelineVarNames) {
    $v = Get-Variable -Name $n -Scope Script -ErrorAction SilentlyContinue
    $script:TimelineVars[$n] = @{ Has = [bool]$v; Value = $(if ($v) { $v.Value } else { $null }) }
  }
  foreach ($n in $script:TimelineMocks.Keys) { Set-TimelineFunction $n (Get-Item ("function:" + $script:TimelineMocks[$n])).ScriptBlock }
  Set-Alias -Name Start-Sleep -Value Step-FakeClock -Scope Script
}

function Restore-TimelineFakes {
  foreach ($n in @($script:TimelineKept.Keys)) {
    if ($script:TimelineKept[$n]) { Set-Item -Path ("function:script:" + $n) -Value $script:TimelineKept[$n] }
    else { Remove-Item -Path ("function:" + $n) -ErrorAction SilentlyContinue }
  }
  Remove-Item -Path Alias:Start-Sleep -ErrorAction SilentlyContinue
  foreach ($n in @($script:TimelineVars.Keys)) {
    if ($script:TimelineVars[$n].Has) { Set-Variable -Name $n -Scope Script -Value $script:TimelineVars[$n].Value }
    else { Remove-Variable -Name $n -Scope Script -ErrorAction SilentlyContinue }
  }
  $script:TimelineEvents.Clear()
  $script:UiKeys.Clear()
  $script:TimelineKept = @{}
}
function Get-TimelineLeftovers {
  $left = @($script:TimelineMocks.Keys | Where-Object { $f = Get-Item ("function:" + $_) -ErrorAction SilentlyContinue; $f -and $f.ScriptBlock.ToString() -ceq (Get-Item ("function:" + $script:TimelineMocks[$_])).ScriptBlock.ToString() })
  return "reste : " + ($left -join ", ") + $(if (Get-Alias -Name Start-Sleep -ErrorAction SilentlyContinue) { " Start-Sleep" })
}
function Start-TimelineCase {
  param([int]$Accounts)
  $script:TimelineAccounts = $Accounts
  $script:FakeOrigin = $script:FakeOrigin + 100000
  $script:FakeNow = $script:FakeOrigin + 1000
  $script:TimelineGuardAt = 0.0
  $script:TimelineEvents.Clear()
  $script:TimelineLog.Clear()
  $script:UiKeys.Clear()
  $script:InputGate = @{ OpenAt = [double]::MinValue; Held = @{} }
  foreach ($n in "UiQuit", "UiOn", "MenuRestart") { Set-Variable -Name $n -Scope Script -Value $false }
  $script:TimelineHeld = @()
  $script:ClmCheck = $null
  $script:Startup = $null
}

function Invoke-TimelineMenu {
  param([int]$Accounts, [object[]]$Specs, [int[]]$Held = @())
  Start-TimelineCase $Accounts
  $script:TimelineHeld = $Held
  Add-TimelineEvents $Specs
  $label = $null
  try {
    $out = @(Invoke-AccountMenu $false)
    $acc = $out[$out.Count - 1]
    if ($acc) { $label = $acc.Label }
  } catch { $label = "erreur " + $_.Exception.Message }
  return @{ Label = $label; End = ($script:FakeNow - $script:FakeOrigin); UiOn = $script:UiOn }
}

function Get-BoundText {
  param([double]$Value, [double]$Min = -1e9, [double]$Max = 1e9)
  if ($Value -ge $Min -and $Value -le $Max) { return "dans les bornes" }
  return "" + $Value + " (bornes " + $Min + " a " + $Max + ")"
}
