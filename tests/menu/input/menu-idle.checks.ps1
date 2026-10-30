. (Join-Path $bin "menu/loop/claude-menu-loop.ps1")
. (Join-Path $bin "menu/startup/claude-menu-startup.ps1")
. (Join-Path $PSScriptRoot "fresh-input-fakes.ps1")

function Get-ReadRun {
  param([string[]]$Log, [int]$Count)
  $seen = 0
  $run = @()
  foreach ($e in $Log) {
    if ($seen -eq 0 -and $e -ne "read") { continue }
    $run += $e
    if ($e -eq "read") { $seen++ }
    if ($seen -ge $Count) { break }
  }
  return ($run -join " ")
}

Install-TimelineFakes
try {
  Set-TimelineFunction "Step-MenuFrame" { $script:TimelineLog.Add("frame"); return $false }

  $r = Invoke-TimelineMenu 3 @(,@(3000, "Escape"))
  $frames = @($script:TimelineLog | Where-Object { $_ -eq "frame" }).Count
  Assert-Null $r.Label "menu au repos : Echap apres une attente sans entree, aucun compte"
  Assert-Equal "dans les bornes" (Get-BoundText $frames -Max 12) "menu au repos : au plus 12 tours de rendu pendant 2 s sans entree"
  Assert-Equal "dans les bornes" (Get-BoundText $r.End -Max 3020) "menu au repos : Echap traitee sans retard"

  $r = Invoke-TimelineMenu 3 @(@(1500, "Down"), @(1500, "Down"), @(1500, "Down"), @(1500, "Up"), @(2000, "Escape"))
  Assert-Null $r.Label "menu au repos : quatre fleches puis Echap, aucun compte"
  Assert-Equal "read read read read" (Get-ReadRun @($script:TimelineLog) 4) "menu au repos : entrees videes avant tout rendu"
} finally {
  Restore-TimelineFakes
}
Assert-Equal "reste : " (Get-TimelineLeftovers) "menu au repos : fonctions et alias rendus"
