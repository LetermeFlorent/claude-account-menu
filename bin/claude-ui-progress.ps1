$script:UiProgress = $null
$script:UiPulse = $null
$script:UiKeys = New-Object 'System.Collections.Generic.Queue[object]'
$script:UiQuit = $false

function Set-UiProgress {
  param([string]$Label, [int]$Pct, [string]$Detail = "")
  $now = Get-NowMs
  $p = $script:UiProgress
  if ($null -eq $p -or $p.Label -ne $Label) {
    $at = [math]::Max(0, $Pct)
    $script:UiProgress = @{ Label = $Label; Pct = $Pct; Detail = $Detail; Bar = (New-Tween $at $at 0 $now) }
    return
  }
  $p.Detail = $Detail
  if ($Pct -ge 0 -and $Pct -ne $p.Pct) { Set-TweenTarget $p.Bar $Pct 350 $now }
  $p.Pct = $Pct
}

function Get-ProgressRow {
  param([int]$W, [double]$Now)
  $p = $script:UiProgress
  $r = New-Row
  $r.Add(@(("  " + $p.Label + "  "), $script:Ink.Text, $false))
  $v = -1.0
  if ($p.Pct -ge 0) { $v = Get-TweenValue $p.Bar $Now }
  Add-ProgressSegs $r $v ([math]::Max(10, [math]::Min(30, $W - 44))) $Now
  if ($p.Pct -ge 0) { $r.Add(@(("  " + [int][math]::Round($v) + " %"), $script:Ink.Text, $false)) }
  $tail = $p.Detail
  if ($script:UiQuit) { $tail = "arret demande, fin de l'operation en cours..." }
  if ($tail) { $r.Add(@(("  " + $tail), $script:Ink.Dim, $false)) }
  return ,$r
}

function Receive-UiKeys {
  try {
    while ($null -ne ($k = Read-UiInput)) {
      if ($k -is [ConsoleKeyInfo] -and [int]$k.KeyChar -eq 3) { $script:UiQuit = $true } else { $script:UiKeys.Enqueue($k) }
    }
  } catch {}
}

function Read-UiKey {
  if ($script:UiKeys.Count -gt 0) { return $script:UiKeys.Dequeue() }
  try { return Read-UiInput } catch {}
  return $null
}

function Wait-Progress {
  param([int]$Ms)
  if (-not $script:UiOn) { Start-Sleep -Milliseconds $Ms; return }
  $end = (Get-NowMs) + $Ms
  do {
    Receive-UiKeys
    if ($null -ne $script:UiPulse) { & $script:UiPulse }
    $left = $end - (Get-NowMs)
    if ($left -gt 0) { Start-Sleep -Milliseconds ([int][math]::Min(33, $left)) }
  } while ((Get-NowMs) -lt $end)
}
