function Start-LockHolder {
  param([string]$Name, [int]$HoldMs, [string]$Then = "", [string]$Text = "")
  $dir = Join-Path $script:Sandbox "lock-holder"
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
  $flag = Join-Path $dir ("held-" + $Name)
  if ([IO.File]::Exists($flag)) { [IO.File]::Delete($flag) }
  $script_ = Join-Path $PSScriptRoot "lock-holder.ps1"
  $kid = Start-RaceChild $script_ @{ Bin = $bin; Dir = $dir; Name = $Name; HoldMs = $HoldMs; Then = $Then; Text = $Text }
  $deadline = [DateTime]::UtcNow.AddMilliseconds($script:RaceReadyMs)
  while (-not [IO.File]::Exists($flag) -and -not $kid.Proc.HasExited -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds $script:RacePollMs }
  return $kid
}
