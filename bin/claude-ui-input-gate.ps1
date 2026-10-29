$script:InputSettleMs = 150
$script:InputHoldMs = 1100
$script:InputRepeatMs = 500
$script:InputGate = @{ OpenAt = [double]::MinValue; Held = @{} }

function Get-InputKeyCode {
  param([int]$Vk, [int]$Char)
  if ($Vk -ne 0) { return $Vk }
  if ($Char -eq 13 -or $Char -eq 10) { return 13 }
  return 65536 + $Char
}

function Get-TrackedKeyCode {
  param($Ev)
  if ($Ev -isnot [ConsoleKeyInfo]) { return $null }
  $code = Get-InputKeyCode ([int]$Ev.Key) ([int]$Ev.KeyChar)
  if ($code -ge 33 -and $code -le 40) { return $null }
  return $code
}

function Test-KeyUpEvent {
  param($Ev)
  return $Ev -is [hashtable] -and $Ev.ContainsKey("KeyUp")
}

function Add-StaleInput {
  param($Ev, [double]$Now)
  $held = $script:InputGate.Held
  $code = Get-TrackedKeyCode $Ev
  if ($null -ne $code) { $held[$code] = @{ At = $Now; Gap = $script:InputHoldMs } }
  elseif (Test-KeyUpEvent $Ev) { $held.Remove([int]$Ev.KeyUp) }
}

function Open-InputGate {
  param([double]$Now, [int[]]$Down = @())
  foreach ($k in $Down) { $script:InputGate.Held[$k] = @{ At = $Now; Gap = $script:InputHoldMs } }
  $script:InputGate.OpenAt = $Now
}

function Test-FreshInput {
  param($Ev, [double]$Now)
  if ($Ev -is [ConsoleKeyInfo] -and [int]$Ev.KeyChar -eq 3) { return $true }
  $gate = $script:InputGate
  if ($Now - $gate.OpenAt -lt $script:InputSettleMs -or (Test-KeyUpEvent $Ev)) { Add-StaleInput $Ev $Now; return $false }
  $code = Get-TrackedKeyCode $Ev
  if ($null -eq $code -or -not $gate.Held.ContainsKey($code)) { return $true }
  $hold = $gate.Held[$code]
  if ($Now - $hold.At -ge $hold.Gap) { $gate.Held.Remove($code); return $true }
  $gate.Held[$code] = @{ At = $Now; Gap = $script:InputRepeatMs }
  return $false
}

function Read-FreshInput {
  while ($null -ne ($ev = Read-UiInput)) {
    if (Test-FreshInput $ev (Get-NowMs)) { return $ev }
  }
  return $null
}

function Clear-SettledInput {
  Clear-UiInput
  Start-Sleep -Milliseconds $script:InputSettleMs
  Clear-ConsoleInput
}
