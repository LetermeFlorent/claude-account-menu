$checkSaved = $script:DriveConfigPath
$checkTrust = $script:DriveFoldersTrustMs
$checkRequest = (Get-Item "function:Invoke-DriveRequest").ScriptBlock
$stampPath = Get-StatePath "drive-folders.done"
[IO.File]::Delete($stampPath)
$script:DriveConfigPath = Join-Path $script:Sandbox "folders-check-drive.json"
$script:FolderCalls = New-Object 'System.Collections.Generic.List[string]'
$script:FolderChildren = '{"files":[{"id":"f1"},{"id":"c1"},{"id":"p1"}]}'

function New-FolderResponse {
  param([string]$Json)
  return [PSCustomObject]@{ RawContentStream = (New-Object IO.MemoryStream(, [Text.Encoding]::UTF8.GetBytes($Json))); Headers = @{} }
}

function Invoke-DriveRequest {
  param([string]$Method, [string]$Uri, $Body = $null, [string]$ContentType = "", [int]$Timeout = 15, [string]$OutFile = "", $Headers = $null)
  $q = [Uri]::UnescapeDataString($Uri)
  $script:FolderCalls.Add($Method + " " + $q)
  if ($q -match "in parents and mimeType") { return New-FolderResponse $script:FolderChildren }
  return New-FolderResponse '{"files":[]}'
}

Save-DriveConfig @{ refreshToken = "r"; folderRoot = "r1"; folderFiles = "f1"; folderCredentials = "c1"; folderPresence = "p1" }
$null = Get-DriveFolders
$firstCalls = $script:FolderCalls.Count
Assert-True ($firstCalls -gt 0) "premier appel : dossiers Drive verifies"
$null = Get-DriveFolders
Assert-Equal $firstCalls $script:FolderCalls.Count "dossiers verifies : second appel sans requete"

Save-DriveConfig @{ refreshToken = "r"; folderRoot = "r1"; folderFiles = "f2"; folderCredentials = "c1"; folderPresence = "p1" }
$script:FolderChildren = '{"files":[{"id":"f2"},{"id":"c1"},{"id":"p1"}]}'
$null = Get-DriveFolders
Assert-True ($script:FolderCalls.Count -gt $firstCalls) "identifiant change dans la config : dossiers verifies de nouveau"

$afterChange = $script:FolderCalls.Count
$null = Get-DriveFolders
Assert-Equal $afterChange $script:FolderCalls.Count "nouvelle config verifiee : second appel sans requete"
Reset-DriveFoldersCheck
$null = Get-DriveFolders
Assert-True ($script:FolderCalls.Count -gt $afterChange) "verification remise a zero : dossiers verifies de nouveau"

$afterReset = $script:FolderCalls.Count
$script:DriveFoldersTrustMs = 0
Start-Sleep -Milliseconds 20
$null = Get-DriveFolders
Assert-True ($script:FolderCalls.Count -gt $afterReset) "verification trop vieille : dossiers verifies de nouveau"

$script:DriveFoldersTrustMs = $checkTrust
Set-Item "function:Invoke-DriveRequest" $checkRequest
Remove-Item -LiteralPath $script:DriveConfigPath -Force
$script:DriveConfigPath = $checkSaved
[IO.File]::Delete($stampPath)
