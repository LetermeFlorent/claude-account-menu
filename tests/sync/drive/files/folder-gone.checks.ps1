$goneRequest = (Get-Item "function:Invoke-DriveRequest").ScriptBlock
$goneConfig = $script:DriveConfigPath
$goneStamp = Get-StatePath "drive-folders.done"
$script:DriveConfigPath = Join-Path $script:Sandbox "folder-gone-drive.json"
$script:GoneStatus = 404
$script:GoneCalls = 0

function Invoke-DriveRequest {
  param($Request)
  $script:GoneCalls++
  $failure = New-Object Exception("status")
  $failure.Data["HttpStatus"] = $script:GoneStatus
  throw $failure
}

function Get-GoneError {
  param([scriptblock]$Action)
  try { $null = & $Action } catch { return $_ }
  return $null
}

try {
  $listed = Get-GoneError { Get-DriveListing "f1" }
  Assert-True ($null -ne $listed -and $listed.Exception.Data["FolderGone"] -eq $true) "listing en 404 : dossier marque disparu"
  $script:GoneStatus = 500
  $listed = Get-GoneError { Get-DriveListing "f1" }
  Assert-True ($null -ne $listed -and $listed.Exception.Data["FolderGone"] -ne $true) "listing en 500 : dossier pas marque disparu"

  Save-DriveConfig @{ refreshToken = "r"; folderRoot = "r1"; folderFiles = "f1"; folderCredentials = "c1"; folderPresence = "p1"; pc = "PCX" }
  Write-MachineStamp "drive-folders" "r1|f1|c1|p1"
  $script:GoneCalls = 0
  $script:GoneRuns = 0
  $script:GoneStatus = 404
  $out = Invoke-WithFolderRetry { $script:GoneRuns++; if ($script:GoneRuns -eq 1) { Get-DriveListing "f1" } else { "ok" } }
  Assert-Equal "ok" ($out | Select-Object -Last 1) "dossier disparu : seconde tentative reussie"
  Assert-Equal 2 $script:GoneRuns "dossier disparu : une seule nouvelle tentative"
  $kept = Read-DriveConfig
  Assert-Equal "" (@("folderRoot", "folderFiles", "folderCredentials", "folderPresence") | Where-Object { $null -ne $kept[$_] }) "dossier disparu : identifiants oublies"
  Assert-Equal "PCX" $kept["pc"] "dossier disparu : le reste de la config est gardee"
  Assert-True ([string]::IsNullOrEmpty((Read-MachineStamp "drive-folders" 60000))) "dossier disparu : verification des dossiers a refaire"

  $script:GoneRuns = 0
  $twice = Get-GoneError { Invoke-WithFolderRetry { $script:GoneRuns++; Get-DriveListing "f1" } }
  Assert-Equal 2 $script:GoneRuns "dossier toujours disparu : deux essais au plus"
  Assert-True ($null -ne $twice) "dossier toujours disparu : erreur rendue"

  $script:GoneRuns = 0
  $other = Get-GoneError { Invoke-WithFolderRetry { $script:GoneRuns++; throw "autre erreur" } }
  Assert-Equal 1 $script:GoneRuns "autre erreur : pas de nouvel essai"
Assert-True ($null -ne $other) "autre erreur : erreur rendue"

  Save-DriveConfig @{ refreshToken = "r"; folderRoot = "r1"; folderFiles = "f1"; folderCredentials = "c1"; folderPresence = "p1" }
  [IO.File]::Delete($goneStamp)
  Assert-Null (Get-CachedDriveFolders) "racine disparue en 404 : cache des dossiers abandonne"
} finally {
  Set-Item "function:Invoke-DriveRequest" $goneRequest
  $script:DriveConfigPath = $goneConfig
  [IO.File]::Delete($goneStamp)
}
