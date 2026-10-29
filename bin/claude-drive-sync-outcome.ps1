. Import-ClmModule claude-drive-lock, claude-drive-config, claude-drive-folders
$script:DriveSharedText = "faite par un autre clm"

function Test-DriveSyncClean {
  param($Res)
  return $Res.Ok -and -not $Res.Error -and $Res.Left -eq 0 -and -not $Res.Stopped
}

function Set-DriveSyncOutcome {
  param($Res, [string]$Run)
  if ($Run -eq "left") { $Res.Ok = $true; $Res.Busy = $true; return }
  if ($Run -eq "done" -and $Res.Error) { try { Reset-DriveFoldersCheck } catch { Write-Verbose $_.Exception.Message } }
  if ($Run -ne "skipped") { return }
  $Res.Ok = $true
  $Res.Shared = $true
  $Res.Away = $null
  $Res.At = Get-DriveLastSync
}

function Set-DriveSyncError {
  param($Res, $ErrorRecord)
  if (Test-LeftToOtherClm $ErrorRecord) { $Res.Ok = $true; $Res.Error = ""; $Res.Busy = $true; return }
  $Res.Ok = $false
  $Res.Error = $ErrorRecord.Exception.Message
  try { Reset-DriveFoldersCheck } catch { Write-Verbose $_.Exception.Message }
}

function Get-DriveSyncElsewhereText {
  param($Res)
  if ($Res.Shared) { return $script:DriveSharedText }
  return $script:LeftToOtherClm
}
