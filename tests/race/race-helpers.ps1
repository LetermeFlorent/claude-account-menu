$script:RaceWaitMs = 120000
$script:RaceReadyMs = 60000
$script:RacePollMs = 25

function Start-RaceChild {
  param([string]$Script, [hashtable]$Params, [hashtable]$Env = @{})
  $psi = New-Object Diagnostics.ProcessStartInfo
  $psi.FileName = (Get-Process -Id $PID).Path
  $parts = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ('"' + $Script + '"'))
  foreach ($k in $Params.Keys) { $parts += @(("-" + $k), ('"' + $Params[$k] + '"')) }
  $psi.Arguments = $parts -join " "
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $psi.RedirectStandardInput = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  foreach ($k in $Env.Keys) {
    if ($null -eq $Env[$k]) { $psi.EnvironmentVariables.Remove($k) } else { $psi.EnvironmentVariables[$k] = [string]$Env[$k] }
  }
  $p = [Diagnostics.Process]::Start($psi)
  try { $p.PriorityClass = "BelowNormal" } catch { Write-Verbose $_.Exception.Message }
  return [PSCustomObject]@{ Proc = $p; Out = $p.StandardOutput.ReadToEndAsync(); Err = $p.StandardError.ReadToEndAsync() }
}

function Wait-RaceChild {
  param($Child, [int]$TimeoutMs = $script:RaceWaitMs)
  $p = $Child.Proc
  $done = $p.WaitForExit($TimeoutMs)
  if (-not $done) { try { $p.Kill() } catch { Write-Verbose $_.Exception.Message } }
  $p.WaitForExit()
  $r = [PSCustomObject]@{ Code = $p.ExitCode; Out = ("" + $Child.Out.Result).Trim(); Err = ("" + $Child.Err.Result).Trim(); TimedOut = -not $done }
  $p.Dispose()
  return $r
}

function Open-RaceGate {
  param([string]$Dir, [int]$Count)
  $deadline = [DateTime]::UtcNow.AddMilliseconds($script:RaceReadyMs)
  while (@(Get-ChildItem -LiteralPath $Dir -Filter "ready-*").Count -lt $Count -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds $script:RacePollMs }
  [IO.File]::WriteAllText((Join-Path $Dir "go"), "go")
}

function Wait-RaceGate {
  param([string]$Dir, [string]$Id)
  [IO.File]::WriteAllText((Join-Path $Dir ("ready-" + $Id)), $Id)
  while (-not [IO.File]::Exists((Join-Path $Dir "go"))) { Start-Sleep -Milliseconds 2 }
}

function Invoke-Race {
  param([string]$Script, [hashtable[]]$Params, [string]$Gate, [hashtable]$Env = @{})
  $kids = @(foreach ($p in $Params) { Start-RaceChild $Script $p $Env })
  Open-RaceGate $Gate $kids.Count
  return @(foreach ($k in $kids) { Wait-RaceChild $k })
}

function Format-RaceFailures {
  param($Results)
  return (@(foreach ($r in $Results) { if ($r.Code -ne 0 -or $r.Err -or $r.TimedOut) { "code " + $r.Code + " : " + $r.Err } }) -join " | ")
}
