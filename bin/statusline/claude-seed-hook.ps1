. Import-ClmModule claude-json
$script:SeedFile = "claude-statusline-seed.ps1"
$script:SeedTokenPattern = '(?<="command"\s*:\s*)"(?:[^"\\]|\\.)*claude-statusline-seed\.ps1(?:[^"\\]|\\.)*"'
$script:WindowsPowerShellTail = "/System32/WindowsPowerShell/v1.0/powershell.exe"
$script:WindowsPowerShellCanon = "C:/Windows" + $script:WindowsPowerShellTail

function Get-PowerShellExe {
  param([string]$Os)
  if ($Os -ne "Windows") {
    $own = $PSHOME + "/pwsh"
    if ($own -notmatch '\s' -and [IO.File]::Exists($own)) { return $own }
    return "pwsh"
  }
  $root = ([string]$env:SystemRoot).Replace("\", "/").TrimEnd("/")
  if (-not $root -or $root -match '\s' -or $root -ieq "C:/Windows") { return $script:WindowsPowerShellCanon }
  return $root + $script:WindowsPowerShellTail
}

function Get-SeedHookCommand {
  param([string]$Os, [string]$Exe = "")
  if (-not $Exe) { $Exe = Get-PowerShellExe $Os }
  $seed = '"$HOME/.local/bin/' + $script:SeedFile + '"'
  if ($Os -eq "Windows") { return $Exe + " -NoProfile -ExecutionPolicy Bypass -File " + $seed }
  return $Exe + " -NoProfile -File " + $seed
}

function Set-SeedCommand {
  param([string]$Text, [string]$Command)
  if (-not $Text.Contains($script:SeedFile)) { return $Text }
  $json = ConvertTo-JsonString $Command
  return [regex]::Replace($Text, $script:SeedTokenPattern, { param($m) $json }.GetNewClosure())
}
