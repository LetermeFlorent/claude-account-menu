$script:MenuIdleMs = 200
$script:MenuIdleSliceMs = 10
$script:MenuWebIdleMs = 50
$script:MenuFrameMs = 33

function Test-UiInputPending {
  if ($script:UiKeys.Count -gt 0) { return $true }
  return Test-ConsoleInputPending
}

function Wait-UiInput {
  param([int]$Ms)
  $end = (Get-NowMs) + $Ms
  while ((Get-NowMs) -lt $end -and -not (Test-UiInputPending)) { Start-Sleep -Milliseconds $script:MenuIdleSliceMs }
}

function Wait-MenuTurn {
  param($Act)
  $acted = $Act.Name -ne "none"
  if ($acted -and (Test-UiInputPending)) { return }
  $drawn = Step-MenuFrame
  if ($acted) { return }
  if ($drawn) { Wait-UiInput $script:MenuFrameMs; return }
  if ($null -ne $script:Web) { Wait-UiInput $script:MenuWebIdleMs } else { Wait-UiInput $script:MenuIdleMs }
}
