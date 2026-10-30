if (-not (Test-Path Function:\Import-ClmModule)) { . (Join-Path $PSScriptRoot "../../claude-import.ps1") }
. Import-ClmModule claude-ui-conin, claude-ui-input-gate
$script:MouseMode = -1

function Enable-UiMouse {
  if ($script:OsName -ne "Windows" -or $script:MouseMode -ge 0 -or -not (Test-RichTerminal)) { return }
  if (-not (Initialize-ConIn)) { return }
  try { $script:MouseMode = [ClmConIn]::Enable() } catch { $script:MouseMode = -1 }
}

function Disable-UiMouse {
  if ($script:MouseMode -lt 0) { return }
  try { [ClmConIn]::Restore($script:MouseMode) } catch { Write-Verbose $_.Exception.Message }
  $script:MouseMode = -1
}

function New-KeyInfo {
  param([string]$Name)
  if ($Name -match "^Entree") { return New-Object System.ConsoleKeyInfo ([char]13), ([ConsoleKey]::Enter), $false, $false, $false }
  if ($Name -eq "Espace") { return New-Object System.ConsoleKeyInfo ([char]32), ([ConsoleKey]::Spacebar), $false, $false, $false }
  if ($Name -eq "Echap" -or $Name -eq "autre touche") { return New-Object System.ConsoleKeyInfo ([char]27), ([ConsoleKey]::Escape), $false, $false, $false }
  if ($Name -eq "Suppr") { return New-Object System.ConsoleKeyInfo ([char]0), ([ConsoleKey]::Delete), $false, $false, $false }
  if ($Name -eq "up") { return New-Object System.ConsoleKeyInfo ([char]0), ([ConsoleKey]::UpArrow), $false, $false, $false }
  if ($Name -eq "down") { return New-Object System.ConsoleKeyInfo ([char]0), ([ConsoleKey]::DownArrow), $false, $false, $false }
  if ($Name.Length -ne 1) { return $null }
  $c = $Name[0]
  return New-Object System.ConsoleKeyInfo $c, ([ConsoleKey][int][char]::ToUpperInvariant($c)), $false, $false, $false
}

function Get-FooterKeyAt {
  param($Rows, [int]$X, [int]$Y)
  if ($null -eq $Rows -or $Y -lt 0 -or $Y -ge $Rows.Count) { return $null }
  $pos = 0
  foreach ($s in $Rows[$Y]) {
    $len = ([string]$s[0]).Length
    if ($X -ge $pos -and $X -lt $pos + $len) {
      if ($s.Count -gt 3) { return $s[3] }
      return $null
    }
    $pos += $len
  }
  return $null
}

function ConvertFrom-MouseEvent {
  param([int[]]$Ev, $Rows, [int]$Top = 0)
  $x = $Ev[1]
  $y = $Ev[2] - $Top
  if ($Ev[3] -eq 3) {
    if ($Ev[4] -gt 0) { return New-KeyInfo "up" }
    return New-KeyInfo "down"
  }
  $name = Get-FooterKeyAt $Rows $x $y
  if ($name) {
    if ($Ev[3] -eq 2) { return $null }
    return New-KeyInfo $name
  }
  $kind = "click"
  if ($Ev[3] -eq 2) { $kind = "double" }
  return @{ Mouse = $kind; X = $x; Y = $y }
}

function Read-UiInput {
  if ($script:MouseMode -lt 0) {
    if ([Console]::KeyAvailable) { return [Console]::ReadKey($true) }
    return $null
  }
  while ($true) {
    $ev = [ClmConIn]::Next()
    if ($null -eq $ev) { return $null }
    if ($ev[0] -eq 1) {
      if ([Console]::KeyAvailable) { return [Console]::ReadKey($true) }
      return $null
    }
    if ($ev[0] -eq 3) { return @{ KeyUp = (Get-InputKeyCode $ev[1] $ev[2]) } }
    $top = 0
    try { $top = [Console]::WindowTop } catch { Write-Verbose $_.Exception.Message }
    $m = ConvertFrom-MouseEvent $ev $script:LastRows $top
    if ($null -ne $m) { return $m }
  }
}
