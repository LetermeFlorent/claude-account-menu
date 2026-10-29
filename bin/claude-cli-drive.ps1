if (-not (Test-Path Function:\Import-ClmModule)) { . (Join-Path $PSScriptRoot "claude-import.ps1") }
. Import-ClmModule claude-text
$script:PrefsIdKinds = @{ skills = "skill"; mcp = "mcp"; globals = "global" }
function Get-DriveOffText {
  return Get-ClmText "drive.off"
}

function Get-CliMcpModeLine {
  param($Catalog)
  if (@($Catalog.Waiting).Count -gt 0) { return Get-ClmText "drive.status.mcp.waiting" @((@($Catalog.Waiting) -join ", ")) }
  if (-not $Catalog.PerPc) { return Get-ClmText "drive.status.mcp.perpc.later" }
  return Get-ClmText "drive.status.mcp.perpc"
}

function Get-CliDriveLines {
  if (-not (Test-DriveConnected)) { return ,[string[]]@((Get-DriveOffText)) }
  $auto = Get-ClmText "drive.status.auto.off"
  if (Test-DriveAuto) { $auto = Get-ClmText "drive.status.auto.on" }
  $last = Get-ClmText "drive.status.last.never"
  $at = Get-DriveLastSync
  if ($at -gt 0) { $last = [DateTimeOffset]::FromUnixTimeSeconds($at).LocalDateTime.ToString($script:CliDateFormat) }
  $key = Get-ClmText "drive.status.key.missing"
  if (Test-SyncKeyStored) { $key = Get-ClmText "drive.status.key.stored" }
  $lines = @((Get-ClmText "drive.status.connected"), (Get-ClmText "drive.status.pc" @((Get-DrivePcName))), (Get-ClmText "drive.status.auto" @($auto)), (Get-ClmText "drive.status.last" @($last)), (Get-ClmText "drive.status.key" @($key)))
  if (Test-DriveLockHeld) { $lines += Get-ClmText "drive.status.busy" }
  return ,[string[]]@($lines + (Get-CliMcpModeLine (Read-SyncCatalog)))
}

function Get-PrefsId {
  param($Item)
  return $script:PrefsIdKinds[$Item.Kind] + ":" + $Item.Key
}

function Read-CliPrefs {
  if (-not (Test-DriveConnected)) { throw (Get-DriveOffText) }
  $catalog = Read-SyncCatalog
  $choice = Read-SyncChoice
  $lines = Get-PrefsLines $choice $catalog (Get-GlobalNames @(Get-Accounts))
  return @{ Catalog = $catalog; Choice = $choice; Lines = $lines }
}

function Format-PrefsItem {
  param($Item)
  $box = "[ ]"
  if ($Item.On -and -not $Item.Erasing) { $box = "[x]" }
  elseif ($Item.Mixed) { $box = "[-]" }
  $t = "  " + $box + " " + (Get-PrefsId $Item)
  if ($Item.All) { $t += "  " + $Item.Label }
  if ($Item.Tag) { $t += "  " + $Item.Tag }
  if ($Item.Erasing) { $t += "  " + (Get-ClmText "drive.prefs.erasing") }
  return $t
}

function Get-CliPrefsLines {
  $p = Read-CliPrefs
  if ($p.Lines.Count -eq 0) { return ,[string[]]@((Get-ClmText "drive.prefs.none")) }
  $out = New-Object 'System.Collections.Generic.List[string]'
  $out.Add($script:PrefsTitle + ", " + (Get-CliMcpModeLine $p.Catalog))
  foreach ($l in $p.Lines) {
    if ($l.Head) { $out.Add($l.Label) }
    else { $out.Add((Format-PrefsItem $l)) }
  }
  return ,$out.ToArray()
}

function Find-PrefsItems {
  param($Lines, [string]$Ref)
  $kind = ""
  $name = $Ref
  if ($Ref -match "^(skill|mcp|global):(.+)$") { $kind = $Matches[1]; $name = $Matches[2] }
  $items = @($Lines | Where-Object { -not $_.Head -and (-not $kind -or $script:PrefsIdKinds[$_.Kind] -eq $kind) })
  $hit = @($items | Where-Object { $_.Key -ceq $name })
  if ($hit.Count -eq 0) { $hit = @($items | Where-Object { $_.Label -eq $name }) }
  return ,$hit
}

function Resolve-PrefsItems {
  param($Lines, [string[]]$Refs)
  if ($Refs.Count -eq 0) { throw (Get-ClmText "drive.prefs.ref.missing") }
  foreach ($r in $Refs) {
    $hit = Find-PrefsItems $Lines $r
    if ($hit.Count -eq 0) { throw (Get-ClmText "drive.prefs.unknown" @($r)) }
    if ($hit.Count -gt 1) { throw (Get-ClmText "drive.prefs.ambiguous" @($r, (@($hit | ForEach-Object { Get-PrefsId $_ }) -join ", "))) }
    $hit[0]
  }
}

function Set-CliPrefsItem {
  param($Choice, $Item, [string]$Move)
  if ($Move -eq "erase") { Add-EraseRequest $Choice $Item.Kind $Item.Key; return }
  if ($Item.All) { foreach ($one in $Item.Items) { Set-PrefsState $Choice $one ($Move -eq "on") }; return }
  Set-PrefsState $Choice $Item ($Move -eq "on")
}

function Invoke-CliPrefsChange {
  param([string]$Move, [string[]]$Refs, [bool]$Yes)
  $prefsPicked = @(Resolve-PrefsItems (Read-CliPrefs).Lines $Refs)
  if ($Move -eq "erase" -and @($prefsPicked | Where-Object { $_.All }).Count -gt 0) { throw (Get-ClmText "drive.prefs.group.erase") }
  if ($Move -eq "erase" -and -not $Yes) {
    foreach ($i in $prefsPicked) { Write-Host (Get-ClmText "drive.prefs.erase.line" @((Get-PrefsId $i), $script:PrefsEraseWarn[$i.Kind].Trim())) }
    throw (Get-ClmText "drive.prefs.yes")
  }
  $prefsMove = $Move
  $null = Update-SyncChoice { param($c) foreach ($i in $prefsPicked) { Set-CliPrefsItem $c $i $prefsMove } }
  foreach ($l in (Read-CliPrefs).Lines) { if (@($prefsPicked | Where-Object { $_.Kind -eq $l.Kind -and $_.Key -ceq $l.Key }).Count -gt 0) { Write-Host (Format-PrefsItem $l) } }
  Write-Host (Get-ClmText "drive.prefs.saved")
  return Invoke-DriveCliSync $false
}
