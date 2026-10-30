. Import-ClmModule claude-theme, claude-ui-term, claude-ui-wt-theme, claude-ui-osc

function ConvertFrom-ColorFgBg {
  param([string]$Value)
  $parts = $Value.Split(";")
  $bg = $parts[$parts.Count - 1].Trim()
  if ($bg -notmatch "^\d+$") { return "" }
  $n = [int]$bg
  if ($n -le 6 -or $n -eq 8) { return "dark" }
  if ($n -le 15) { return "light" }
  return ""
}

function Get-TerminalTheme {
  param([string]$Os = $script:OsName, $Vars = $null, [bool]$Rich = $false, [scriptblock]$OscReader = $null)
  $t = ConvertFrom-ColorFgBg (Read-EnvVar "COLORFGBG" $Vars)
  if ($t) { return $t }
  $t = Get-WtTheme $Vars
  if ($t) { return $t }
  return "" + (Get-OscTheme $Os $Vars $Rich $OscReader)
}

function Get-AutoTheme {
  param([string]$Os = $script:OsName, $Vars = $null, [scriptblock]$Terminal = $null, [scriptblock]$System = $null)
  if ($null -eq $Terminal) { $Terminal = { param($O, $V) Get-TerminalTheme $O $V (Test-RichTerminal) } }
  if ($null -eq $System) { $System = { param($O, $V) Get-SystemTheme $O $V } }
  if ($null -eq $script:TerminalTheme) {
    $script:TerminalTheme = ""
    try { $script:TerminalTheme = "" + (& $Terminal $Os $Vars) } catch { Write-Verbose $_.Exception.Message }
  }
  if ($script:TerminalTheme) { return $script:TerminalTheme }
  $t = $null
  try { $t = & $System $Os $Vars } catch { Write-Verbose $_.Exception.Message }
  if ($t) { return $t }
  return "dark"
}

function Get-ConsoleTheme {
  param([string]$Os = $script:OsName, $Vars = $null)
  $t = Get-FixedTheme $Vars
  if ($t) { return $t }
  return Get-AutoTheme $Os $Vars
}
