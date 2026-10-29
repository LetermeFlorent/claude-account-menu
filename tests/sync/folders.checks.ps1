$foldersSaved = $script:DriveConfigPath
[IO.File]::Delete((Get-StatePath "drive-folders.done"))
$script:DriveConfigPath = Join-Path $script:Sandbox "folders-drive.json"
$script:FolderCalls = New-Object 'System.Collections.Generic.List[string]'
$script:FolderChildren = '{"files":[{"id":"f1"},{"id":"c1"},{"id":"p1"}]}'
$script:FolderNew = 0

function New-FolderResponse {
  param([string]$Json)
  return [PSCustomObject]@{ RawContentStream = (New-Object IO.MemoryStream(, [Text.Encoding]::UTF8.GetBytes($Json))); Headers = @{} }
}

function Invoke-DriveRequest {
  param([string]$Method, [string]$Uri, $Body = $null, [string]$ContentType = "", [int]$Timeout = 15, [string]$OutFile = "", $Headers = $null)
  $q = [Uri]::UnescapeDataString($Uri)
  $script:FolderCalls.Add($Method + " " + $q)
  if ($Method -eq "POST") { $script:FolderNew++; return New-FolderResponse ('{"id":"new' + $script:FolderNew + '"}') }
  if ($q -match "'r1' in parents and mimeType") { return New-FolderResponse $script:FolderChildren }
  return New-FolderResponse '{"files":[]}'
}

Save-DriveConfig @{ refreshToken = "r"; folderRoot = "r1"; folderFiles = "f1"; folderCredentials = "c1"; folderPresence = "p1" }
$f = Get-DriveFolders
Assert-Equal "r1 f1 c1 p1" ($f.Root + " " + $f.Files + " " + $f.Credentials + " " + $f.Presence) "dossiers Drive en cache valides : gardes"
Assert-Equal 0 $script:FolderNew "dossiers Drive valides : rien cree"

$script:FolderChildren = '{"files":[{"id":"c1"},{"id":"p1"}]}'
Reset-DriveFoldersCheck
$f = Get-DriveFolders
Assert-Equal "new1" $f.Root "dossier files mis a la corbeille : arborescence recreee"
Assert-Equal "new2" $f.Files "dossier files mis a la corbeille : nouveau dossier files"
Assert-Equal "new2" (Read-DriveConfig)["folderFiles"] "nouveaux dossiers gardes dans la config"

Save-DriveConfig @{ refreshToken = "r"; folderRoot = "r1"; folderFiles = "f1"; folderCredentials = "c1"; folderPresence = "p1" }
$script:FolderChildren = '{"files":[]}'
Reset-DriveFoldersCheck
$lock = Open-MachineLock "drive-folders"
$script:DriveFoldersWaitMs = 0
try { $err = ""; try { $null = Get-DriveFolders } catch { $err = $_.Exception.Message } } finally { Close-MachineLock $lock }
Assert-Equal "laissee a un autre clm" $err "creation des dossiers Drive sous verrou"

$c = @{ refreshToken = "r"; folderRoot = "r1"; folderFiles = "f1"; folderCredentials = "c1"; folderPresence = "p1"; lastSync = 5; pc = "PC" }
Clear-DriveFolders $c
Assert-Equal "pc,refreshToken" ((@($c.Keys) | Sort-Object) -join ",") "connexion a un autre Drive : dossiers et derniere synchro oublies"

Remove-Item -LiteralPath $script:DriveConfigPath -Force
$script:DriveConfigPath = $foldersSaved
[IO.File]::Delete((Get-StatePath "drive-folders.done"))
. (Join-Path $bin "claude-drive-folders.ps1")
