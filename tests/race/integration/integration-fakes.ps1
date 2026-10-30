. (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) "drive") "drive-race-store.ps1")

[Net.WebRequest]::DefaultWebProxy = New-Object Net.WebProxy("http://127.0.0.1:9")

function New-ItestRunspace {
  $rs = [RunspaceFactory]::CreateRunspace()
  $rs.Open()
  $ps = [PowerShell]::Create()
  $ps.Runspace = $rs
  [void]$ps.AddScript('param($Seed) . $Seed').AddArgument(${function:New-ItestRunspace}.File)
  [void]$ps.Invoke()
  $ps.Dispose()
  return $rs
}

function Invoke-ItestFreshSync {
  param($Ctl, [long]$DeadlineMs, [bool]$Force)
  Add-ItestMark "fresh"
  $ps = [PowerShell]::Create()
  $ps.Runspace = New-ItestRunspace
  try {
    [void]$ps.AddScript($script:FreshSyncScript).AddArgument($script:FreshSyncSource).AddArgument($Ctl).AddArgument($DeadlineMs).AddArgument($Force)
    $out = @($ps.Invoke())
    if ($out.Count -gt 0 -and $out[-1] -is [hashtable]) { return $out[-1] }
    throw ("synchro fraiche sans resultat : " + ($ps.Streams.Error -join " ; "))
  } finally { $ps.Runspace.Dispose(); $ps.Dispose() }
}

function Add-ItestMark {
  param([string]$Kind)
  [IO.File]::WriteAllText((Join-Path $env:CLM_ITEST_LOG ($Kind + "-" + $PID + "-" + [guid]::NewGuid().ToString("N"))), ($env:CLM_ITEST_ID + " " + $env:CLM_ITEST_STARTS))
}

function Stop-ItestNetwork { throw "reseau interdit pendant les tests" }
function Stop-ItestToken { throw "jeton interdit pendant les tests" }
function Stop-ItestKeyStore { throw "trousseau interdit pendant les tests" }
function Read-ItestSyncKey { return ConvertTo-SyncKeyRecord (Get-DriveRaceKeys) }
function Test-ItestNetwork { return $true }
function Start-ItestDriveWatcher { Add-ItestMark "watcher"; return $false }

function Invoke-ItestGitHubGet {
  param([string]$Uri, [int]$Timeout, [string]$OutFile = "")
  Add-ItestMark "github"
  $name = "release.json"
  if ($Uri.EndsWith(".zip")) { $name = "clm.zip" } elseif ($Uri.EndsWith(".sha256")) { $name = "clm.zip.sha256" }
  $path = Join-Path $env:CLM_ITEST_RELEASE $name
  if ($OutFile) { Copy-Item -LiteralPath $path -Destination $OutFile; return $null }
  return [PSCustomObject]@{ Content = [IO.File]::ReadAllText($path) }
}

function Read-ItestCredential {
  param($Acc)
  return [PSCustomObject]@{ claudeAiOauth = [PSCustomObject]@{ accessToken = "faux"; expiresAt = 4102444800000; subscriptionType = "pro" } }
}

function Get-ItestUsageToken {
  param($Acc, $Cred, [switch]$NoRefresh)
  return @{ Token = "faux" }
}

function Invoke-ItestUsageApi {
  param([string]$Token)
  Add-ItestMark "usage"
  Start-Sleep -Milliseconds 300
  return [PSCustomObject]@{ five_hour = [PSCustomObject]@{ utilization = 42; resets_at = "2030-01-01T00:00:00Z" }; seven_day = [PSCustomObject]@{ utilization = 7; resets_at = "2030-01-03T00:00:00Z" } }
}

function Get-ItestDriveFolders { return @{ Root = "R"; Files = "F"; Credentials = "C"; Presence = "P" } }
function Sync-ItestDriveCredentials { param($Folders, $Accs, $Keys) return 0 }

function Get-ItestDriveListing {
  param([string]$FolderId)
  Add-ItestMark "drive"
  $map = New-PathMap
  foreach ($e in (Read-DriveRaceEntries $env:CLM_ITEST_DRIVE $FolderId)) { if ($null -eq $map[$e.Name]) { $map[$e.Name] = $e } }
  return $map
}

function Get-ItestDriveFilesListing { param($Folders, [string]$Pc) return Get-ItestDriveListing $Folders.Files }

function Send-ItestDriveContent {
  param([string]$FolderId, [string]$Name, [byte[]]$Bytes, $Props, [string]$Id)
  $all = @{}
  if ($Id) {
    $path = Find-DriveRaceFile $env:CLM_ITEST_DRIVE $Id
    if (-not $path) { throw ("fichier Drive introuvable : " + $Id) }
    $old = Read-DriveRaceEntry $path
    $FolderId = $old.Folder
    foreach ($k in $old.Props.Keys) { $all[$k] = $old.Props[$k] }
  } else { $Id = "id" + [guid]::NewGuid().ToString("N") }
  if ($null -ne $Props) { foreach ($k in $Props.Keys) { $all[$k] = [string]$Props[$k] } }
  return Write-DriveRaceEntry $env:CLM_ITEST_DRIVE $FolderId $Id $Name $all $Bytes
}

function Get-ItestDriveBytes {
  param([string]$Id)
  $path = Find-DriveRaceFile $env:CLM_ITEST_DRIVE $Id
  if (-not $path) { throw ("fichier Drive introuvable : " + $Id) }
  return ,(Read-DriveRaceEntry $path).Bytes
}

function Remove-ItestDriveFiles {
  param([string[]]$Ids, $Ctl, [long]$DeadlineMs)
  foreach ($id in $Ids) { $path = Find-DriveRaceFile $env:CLM_ITEST_DRIVE $id; if ($path) { [IO.File]::Delete($path) } }
  return $Ids.Count
}

function Set-ItestDriveProps {
  param([string]$Id, $Props)
  $path = Find-DriveRaceFile $env:CLM_ITEST_DRIVE $Id
  if (-not $path) { throw ("fichier Drive introuvable : " + $Id) }
  $old = Read-DriveRaceEntry $path
  foreach ($k in $Props.Keys) { $old.Props[$k] = [string]$Props[$k] }
  $null = Write-DriveRaceEntry $env:CLM_ITEST_DRIVE $old.Folder $Id $old.Name $old.Props $old.Bytes
}

$itestFakes = @{
  "Invoke-WebRequest" = "Stop-ItestNetwork"; "Invoke-RestMethod" = "Stop-ItestNetwork"; "Update-AccountToken" = "Stop-ItestToken"
  "Test-Network" = "Test-ItestNetwork"; "Start-DriveWatcher" = "Start-ItestDriveWatcher"; "Invoke-GitHubGet" = "Invoke-ItestGitHubGet"
  "Read-AccountCredential" = "Read-ItestCredential"; "Get-UsageToken" = "Get-ItestUsageToken"; "Invoke-UsageApi" = "Invoke-ItestUsageApi"
  "Get-DriveFolders" = "Get-ItestDriveFolders"; "Sync-DriveCredentials" = "Sync-ItestDriveCredentials"; "Get-DriveListing" = "Get-ItestDriveListing"
  "Get-DriveFilesListing" = "Get-ItestDriveFilesListing"; "Send-DriveContent" = "Send-ItestDriveContent"; "Get-DriveBytes" = "Get-ItestDriveBytes"
  "Remove-DriveFiles" = "Remove-ItestDriveFiles"; "Remove-DriveFile" = "Remove-ItestDriveFiles"; "Set-DriveProps" = "Set-ItestDriveProps"
  "Invoke-FreshDriveSync" = "Invoke-ItestFreshSync"; "Read-SyncKeyText" = "Read-ItestSyncKey"; "Write-SyncKeyText" = "Stop-ItestKeyStore"
}
foreach ($itestName in $itestFakes.Keys) { Set-Alias -Name $itestName -Value $itestFakes[$itestName] -Scope Global -Force }
