function Get-DriveRaceKind {
  param($Run, [string]$Id)
  if ($Run.Out -cmatch ("^result " + $Id + " (done|skipped|left)$")) { return $Matches[1] }
  return ""
}

function Read-DriveRaceJson {
  param([string]$Path)
  if (-not [IO.File]::Exists($Path)) { return $null }
  try { return [IO.File]::ReadAllText($Path) | ConvertFrom-Json } catch { return $null }
}

function Get-DriveRaceFlagKind {
  param($Result)
  if ($Result.Busy) { return "left" }
  if ($Result.Shared) { return "skipped" }
  return "done"
}

function Get-DriveRacePasses {
  param([string]$Dir)
  $passes = @()
  foreach ($log in @(Get-ChildItem -LiteralPath $Dir -Filter "passes-*.log")) {
    $open = $null
    foreach ($line in [IO.File]::ReadAllLines($log.FullName)) {
      $parts = $line.Split(" ")
      if ($parts[0] -eq "start") { $open = [PSCustomObject]@{ Id = $parts[1]; Start = [long]$parts[2]; End = [long]::MaxValue }; $passes += $open }
      elseif ($parts[0] -eq "end" -and $null -ne $open) { $open.End = [long]$parts[2]; $open = $null }
    }
  }
  return ,@($passes | Sort-Object Start)
}

function Get-DriveRaceOverlaps {
  param($Passes)
  $bad = @()
  for ($i = 1; $i -lt $Passes.Count; $i++) {
    $a = $Passes[$i - 1]
    $b = $Passes[$i]
    if ($b.Start -lt $a.End) { $bad += ($a.Id + " " + $a.Start + "-" + $a.End + " / " + $b.Id + " " + $b.Start + "-" + $b.End) }
  }
  return $bad -join " | "
}

function Get-DriveRaceRemoteText {
  param([string]$Store, $Keys)
  $sealedName = $script:SealedPrefix + $script:DriveRaceFileRel
  $all = Read-DriveRaceEntries $Store "F"
  $found = @($all | Where-Object { $_.Name -ceq $sealedName -or $_.Name -ceq $script:DriveRaceFileRel })
  $texts = @(foreach ($e in $found) {
    if ($e.Name -ceq $sealedName) { [Text.Encoding]::UTF8.GetString((Unprotect-SyncBytes $Keys ($script:SealedFilesArea + $script:DriveRaceFileRel) $e.Bytes)) }
    else { [Text.Encoding]::UTF8.GetString($e.Bytes) }
  })
  return $texts -join "|"
}
