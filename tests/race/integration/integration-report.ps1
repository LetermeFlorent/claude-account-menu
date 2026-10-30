. (Join-Path (Split-Path -Parent $PSScriptRoot) "race-helpers.ps1")
. (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) "clm") "restart-launch.ps1")
$script:ItestFailWords = "impossible|erreur|exception|introuvable|interdit|illisible|stuck |loop "

function Start-ItestChild {
  param($Box, [string]$Id, [string]$Mode, [string[]]$Argv = @(), [hashtable]$Extra = @{})
  $vars = @{}
  foreach ($k in $Box.Env.Keys) { $vars[$k] = $Box.Env[$k] }
  foreach ($k in $Extra.Keys) { $vars[$k] = $Extra[$k] }
  $vars["CLM_ITEST_ID"] = $Id
  $vars["CLM_ITEST_MODE"] = $Mode
  return Start-MenuChild (Join-Path $PSScriptRoot "integration-child.ps1") $Argv $vars
}

function Get-ItestMarks {
  param($Box, [string]$Kind)
  return @(Get-ChildItem -LiteralPath $Box.Log -Filter ($Kind + "-*") -File | ForEach-Object { $_.Name })
}

function Get-ItestMarkTexts {
  param($Box, [string]$Kind)
  return @(Get-ItestMarks $Box $Kind | ForEach-Object { [IO.File]::ReadAllText((Join-Path $Box.Log $_)) })
}

function Get-ItestMarkPids {
  param($Box, [string]$Kind)
  return @(Get-ItestMarks $Box $Kind | ForEach-Object { $_.Split("-")[1] } | Sort-Object -Unique)
}

function Wait-ItestMarks {
  param($Box, [string]$Kind, [int]$Count, [int]$TimeoutMs = 45000)
  $clock = [Diagnostics.Stopwatch]::StartNew()
  while (@(Get-ItestMarks $Box $Kind).Count -lt $Count -and $clock.ElapsedMilliseconds -lt $TimeoutMs) { Start-Sleep -Milliseconds 50 }
  return @(Get-ItestMarks $Box $Kind).Count -ge $Count
}

function Get-ItestBadJson {
  param($Box)
  return @(foreach ($f in (Get-ChildItem -LiteralPath $Box.Home -Recurse -Force -File -Filter "*.json")) {
    try { $null = [IO.File]::ReadAllText($f.FullName) | ConvertFrom-Json } catch { $f.FullName }
  })
}

function Test-ItestLockFree {
  param([string]$Path)
  try { $fs = [IO.File]::Open($Path, "Open", "ReadWrite", "None"); $fs.Dispose(); return $true } catch { return $false }
}

function Get-ItestLeftovers {
  param($Box)
  $files = @(Get-ChildItem -LiteralPath $Box.Home -Recurse -Force -File)
  $left = @($files | Where-Object { $_.Name -like "*.tmp" -or $_.Name -eq "clm.installing" } | ForEach-Object { $_.FullName })
  $left += @($files | Where-Object { $_.Name -like "*.lock" -and -not (Test-ItestLockFree $_.FullName) } | ForEach-Object { "verrou tenu " + $_.FullName })
  $left += @(Get-ChildItem -LiteralPath $Box.Tmp -Force | ForEach-Object { $_.FullName })
  return $left
}

function Get-ItestErrors {
  param($Runs)
  return @(foreach ($r in $Runs) {
    if ($r.Code -ne 0 -or $r.TimedOut -or $r.Err) { "code " + $r.Code + " : " + $r.Err }
    foreach ($line in ($r.Out -split "`r?`n")) { if ($line -match $script:ItestFailWords) { $line } }
  })
}

function Get-ItestLastSha {
  param($Run)
  $menus = @(Get-RaceLines $Run "menu")
  if ($menus.Count -eq 0) { return "" }
  return $menus[-1].Split(" ")[2]
}
