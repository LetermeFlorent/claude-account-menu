$script:PrefsIdKinds = @{ skills = "skill"; mcp = "mcp"; globals = "global" }
$script:DriveOffText = "Drive non connecte : clm --drive-login"

function Get-CliMcpModeLine {
  param($Catalog)
  if (@($Catalog.Waiting).Count -gt 0) { return "MCP envoyes en entier tant que ces PC n'ont pas clm a jour : " + (@($Catalog.Waiting) -join ", ") }
  if (-not $Catalog.PerPc) { return "MCP reglables par PC apres la prochaine synchro" }
  return "MCP reglables par PC"
}

function Get-CliDriveLines {
  if (-not (Test-DriveConnected)) { return ,[string[]]@($script:DriveOffText) }
  $auto = "coupee"
  if (Test-DriveAuto) { $auto = "au lancement et a la fermeture de Claude" }
  $last = "jamais"
  $at = Get-DriveLastSync
  if ($at -gt 0) { $last = [DateTimeOffset]::FromUnixTimeSeconds($at).LocalDateTime.ToString($script:CliDateFormat) }
  $key = "absente, clm --sync-key"
  if (Test-SyncKeyStored) { $key = "enregistree" }
  $lines = @("Drive connecte", ("PC : " + (Get-DrivePcName)), ("synchro auto : " + $auto), ("derniere synchro : " + $last), ("phrase de synchro : " + $key))
  if (Test-DriveLockHeld) { $lines += "synchro en cours dans une autre fenetre" }
  return ,[string[]]@($lines + (Get-CliMcpModeLine (Read-SyncCatalog)))
}

function Get-PrefsId {
  param($Item)
  return $script:PrefsIdKinds[$Item.Kind] + ":" + $Item.Key
}

function Read-CliPrefs {
  if (-not (Test-DriveConnected)) { throw $script:DriveOffText }
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
  if ($Item.Erasing) { $t += "  efface a la prochaine synchro" }
  return $t
}

function Get-CliPrefsLines {
  $p = Read-CliPrefs
  if ($p.Lines.Count -eq 0) { return ,[string[]]@("aucun skill ni MCP a regler pour l'instant") }
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
  if ($Refs.Count -eq 0) { throw "donner au moins un id, voir clm --prefs" }
  foreach ($r in $Refs) {
    $hit = Find-PrefsItems $Lines $r
    if ($hit.Count -eq 0) { throw ("reglage inconnu : " + $r + ", voir clm --prefs") }
    if ($hit.Count -gt 1) { throw ("reglage ambigu : " + $r + ", preciser parmi " + (@($hit | ForEach-Object { Get-PrefsId $_ }) -join ", ")) }
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
  if ($Move -eq "erase" -and @($prefsPicked | Where-Object { $_.All }).Count -gt 0) { throw "un groupe entier ne s'efface pas, donner les ids un par un" }
  if ($Move -eq "erase" -and -not $Yes) {
    foreach ($i in $prefsPicked) { Write-Host ("effacer " + (Get-PrefsId $i) + " partout : " + $script:PrefsEraseWarn[$i.Kind].Trim()) }
    throw "ajouter --yes pour confirmer"
  }
  $prefsMove = $Move
  $null = Update-SyncChoice { param($c) foreach ($i in $prefsPicked) { Set-CliPrefsItem $c $i $prefsMove } }
  foreach ($l in (Read-CliPrefs).Lines) { if (@($prefsPicked | Where-Object { $_.Kind -eq $l.Kind -and $_.Key -ceq $l.Key }).Count -gt 0) { Write-Host (Format-PrefsItem $l) } }
  Write-Host "reglages de synchro enregistres, synchro Drive..."
  return Invoke-DriveCliSync $false
}
