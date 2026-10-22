function Get-OutcomeFor {
  param([string[]]$Lines, [int]$Code = 0, [string]$Killed = "")
  $st = New-UpdateState
  foreach ($l in $Lines) { Add-UpdateLine $st $l }
  return Get-UpdateOutcome $st $Code $Killed
}

function New-FakeUpdateProc {
  param([bool]$Exited, [string]$Out, [string]$Err = "", [int]$Code = 0)
  $p = [PSCustomObject]@{ HasExited = $Exited; ExitCode = $Code; Id = 1; Disposed = $false; StandardOutput = (New-Object IO.StringReader $Out); StandardError = (New-Object IO.StringReader $Err) }
  $p | Add-Member -MemberType ScriptMethod -Name Dispose -Value { $this.Disposed = $true }
  return $p
}
