$script:StartupStepHoldMs = 1000
$script:StartupFadeMs = 300

function Get-ShownSteps {
  param($Su)
  return ,@($Su.Steps | Where-Object { -not $_.Gone })
}

function Update-StepFades {
  param($Su, [double]$Now)
  $changed = $false
  foreach ($s in $Su.Steps) {
    if ($s.State -ne "done" -or $s.Kind -eq "failed" -or $s.Gone) { continue }
    if ($null -eq $s.HideAt) { $s.HideAt = $Now + $script:StartupStepHoldMs; continue }
    if ($Now -lt $s.HideAt) { continue }
    if ($null -eq $s.Fade) { $s.Fade = New-Tween 1 0 $script:StartupFadeMs $Now; $changed = $true; continue }
    if (Test-TweenRunning $s.Fade $Now) { continue }
    $s.Gone = $true
    $changed = $true
  }
  return $changed
}

function Step-StartupEnd {
  param($Su, [double]$Now)
  $changed = Update-StepFades $Su $Now
  if ((Get-ShownSteps $Su).Count -gt 0) { return $changed }
  $Su.Hidden = $true
  return $true
}
