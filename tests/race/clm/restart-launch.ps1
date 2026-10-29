$script:RaceDroppedEnv = @("CLAUDE_CONFIG_DIR", "XDG_CACHE_HOME", "XDG_STATE_HOME", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "CLM_RACE_STARTS")

function Get-RaceChildEnv {
  param($RaceHome, [string]$Id)
  $vars = @{}
  foreach ($k in $RaceHome.Env.Keys) { $vars[$k] = $RaceHome.Env[$k] }
  $vars["APPDATA"] = Join-Path (Join-Path $RaceHome.Root "AppData") "Roaming"
  foreach ($k in $script:RaceDroppedEnv) { $vars[$k] = $null }
  $vars["CLM_RACE_ID"] = $Id
  $vars["CLM_RACE_BIN"] = $RaceHome.Bin
  $vars["CLM_RACE_DIR"] = $RaceHome.Root
  return $vars
}

function Start-MenuChild {
  param([string]$Script, [string[]]$Argv, [hashtable]$Env)
  $psi = New-Object Diagnostics.ProcessStartInfo
  $psi.FileName = (Get-Process -Id $PID).Path
  $psi.Arguments = (@("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ('"' + $Script + '"')) + $Argv) -join " "
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

function Get-RaceLines {
  param($Run, [string]$Word)
  return @($Run.Out -split "`r?`n" | Where-Object { $_ -like ($Word + " *") })
}
