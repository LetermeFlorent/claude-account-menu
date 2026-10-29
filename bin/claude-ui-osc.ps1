. Import-ClmModule claude-platform, claude-ui-contrast, claude-ui-osc-read

$script:OscWindowsPrograms = @("vscode", "WezTerm")
$script:OscReplyPattern = '(?<![0-9])11;rgba?:([0-9a-fA-F]{1,4})/([0-9a-fA-F]{1,4})/([0-9a-fA-F]{1,4})(?:/[0-9a-fA-F]{1,4})?[\x07\x1b\\]'

function ConvertFrom-OscReply {
  param([string]$Text)
  if (-not $Text) { return $null }
  $m = [regex]::Match($Text, $script:OscReplyPattern)
  if (-not $m.Success) { return $null }
  $rgb = foreach ($i in 1..3) {
    $hex = $m.Groups[$i].Value
    $max = [math]::Pow(16, $hex.Length) - 1
    [int][math]::Round([Convert]::ToInt32($hex, 16) * 255 / $max, [MidpointRounding]::AwayFromZero)
  }
  return ,@($rgb)
}

function Test-OscCapable {
  param([string]$Os, $Vars = $null, [bool]$Rich = $false)
  if (-not $Rich) { return $false }
  if ((Read-EnvVar "CLM_OSC" $Vars) -eq "0") { return $false }
  $term = Read-EnvVar "TERM" $Vars
  if ($term -eq "dumb" -or $term -match "^(screen|tmux)") { return $false }
  if ($Os -eq "Windows") { return ((Read-EnvVar "WT_SESSION" $Vars) -ne "" -or $script:OscWindowsPrograms -contains (Read-EnvVar "TERM_PROGRAM" $Vars)) }
  return $term -ne ""
}

function Get-OscReaderName {
  param([string]$Os)
  if ($Os -eq "Windows") { return "Read-ConsoleReply" }
  return "Read-TtyReply"
}

function Read-OscBackground {
  param([string]$Os = $script:OsName, [scriptblock]$Reader = $null)
  try {
    if ($null -eq $Reader) { $Reader = (Get-Command (Get-OscReaderName $Os) -CommandType Function).ScriptBlock }
    return ConvertFrom-OscReply ([string](& $Reader))
  } catch {
    Write-Verbose $_.Exception.Message
    return $null
  }
}

function Get-OscTheme {
  param([string]$Os = $script:OsName, $Vars = $null, [bool]$Rich = $false, [scriptblock]$Reader = $null)
  try {
    if (-not (Test-OscCapable $Os $Vars $Rich)) { return "" }
    return Get-BackgroundTheme (Read-OscBackground $Os $Reader)
  } catch {
    Write-Verbose $_.Exception.Message
    return ""
  }
}
