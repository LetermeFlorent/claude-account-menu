. Import-ClmModule claude-self-version, claude-menu-startup
$script:ClmReplacedPollMs = 1000
$script:ClmRestartDue = $false
$script:ClmRestartAt = 0.0
$script:ClmRestartDropped = @("--usage", "--yes", "--force", "--erase", "--updated", "--no-update")
$script:ClmRestartDroppedPattern = "^(-[1-9]|--save(=.*)?|--restore=.*|--only=.*|--sync.*)$"

function Test-ClmRestartHeld {
  $su = $script:Startup
  if ($null -ne $su -and ($null -ne $su.Exit -or $null -ne $su.Pending)) { return $true }
  return (Test-StepsLeft $su @()) -or (Test-DriveJobRunning $script:DriveJob)
}

function Step-ClmRestart {
  param([double]$Now)
  if ($script:ClmRestartDue -or $Now -lt $script:ClmRestartAt) { return }
  $script:ClmRestartAt = $Now + $script:ClmReplacedPollMs
  if (Test-ClmRestartHeld) { return }
  if ((Test-ClmReplaced) -and (Get-ClmSha)) { $script:ClmRestartDue = $true }
}

function Get-ClmRestartAction {
  param($Act)
  if (-not $script:ClmRestartDue -or $Act.Name -ne "none" -or (Test-ClmRestartHeld)) { return $Act }
  $script:ClmUpdated = $true
  return @{ Name = "restart" }
}

function Test-ClmRestartDropped {
  param([string]$Arg)
  if ($Arg -match $script:ClmRestartDroppedPattern -or $script:ClmRestartDropped -contains $Arg) { return $true }
  return @($script:CliCommands) -contains $Arg -or ($null -ne $script:DriveCliFlags -and $script:DriveCliFlags.ContainsKey($Arg))
}

function Get-ClmRestartArgs {
  param([object[]]$Argv)
  $kept = @(foreach ($a in @($Argv)) { if (-not (Test-ClmRestartDropped ([string]$a))) { [string]$a } })
  return ,[string[]]($kept + "--no-update")
}
