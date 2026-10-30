$raceLab = Join-Path (Split-Path -Parent $PSScriptRoot) "race"
. (Join-Path $raceLab "race-helpers.ps1")
. (Join-Path (Join-Path $raceLab "backup") "lock-holder-start.ps1")
. (Join-Path $bin "claude-menu-archive.ps1")
. (Join-Path $bin "claude-menu-save.ps1")
. Import-ClmModule claude-machine-lock
$script:LocksDl = Join-Path $script:Sandbox "verrous dl"
$null = New-Item -ItemType Directory -Path $script:LocksDl -Force
function Get-DownloadsDir { return $script:LocksDl }

$claimFirst = Get-FreeArchivePath "claude-comptes-meme" ".zip"
$claimSecond = Get-FreeArchivePath "claude-comptes-meme" ".zip"
Assert-True ([IO.File]::Exists($claimFirst)) "nom d'archive : reserve sur le disque des qu'il est choisi"
Assert-True ($claimFirst -ne $claimSecond) "meme nom demande deux fois : deux archives distinctes"
Assert-Equal (Join-Path $script:LocksDl "claude-comptes-meme-2.zip") $claimSecond "meme nom demande deux fois : archive voisine"

$keyPath = Get-StatePath $script:BackupKeyName
if ([IO.File]::Exists($keyPath)) { [IO.File]::Delete($keyPath) }
$otherKey = [Convert]::ToBase64String([byte[]](@(7) * $script:BackupKeyBytes))
$keyHolder = Start-LockHolder "backup-key" 1500 $keyPath $otherKey
$mineKey = Get-BackupKey
$null = Wait-RaceChild $keyHolder
Assert-Equal $otherKey ([Convert]::ToBase64String($mineKey)) "cle des archives creee par un autre clm en meme temps : la meme pour tous"
[IO.File]::Delete($keyPath)
$null = Get-BackupKey
if ($script:OsName -ne "Windows") {
  Assert-Equal "-rw-------" (Get-Item -LiteralPath $keyPath).UnixMode "cle des archives creee par clm : lisible par son seul proprietaire"
}

$markFile = New-SandboxFile "verrous dl/claude-comptes-marque.zip" "x"
$markHolder = Start-LockHolder $script:BackupMarksName 6500
$markErr = $null
try { Add-BackupMark $markFile } catch { $markErr = $_.Exception.Message }
$null = Wait-RaceChild $markHolder
Assert-Null $markErr "liste des sauvegardes tenue par un autre clm : attente sans erreur"
Assert-True (Test-BackupListed ([IO.FileInfo]$markFile)) "liste des sauvegardes tenue par un autre clm : sauvegarde listee ensuite"

$restoreZip = Join-Path $script:LocksDl "claude-comptes-absente.zip"
$restoreHeld = Open-MachineLock "backup"
Assert-Throws { Restore-Accounts $restoreZip -Yes } (Get-ClmText "backup.restore.busy") "restauration pendant une autre : dit clairement"
Close-MachineLock $restoreHeld
$restoreHolder = Start-LockHolder "backup" 800
$restoreErr = $null
try { $null = Restore-Accounts $restoreZip -Yes } catch { $restoreErr = $_.Exception.Message }
$null = Wait-RaceChild $restoreHolder
Assert-True (-not ("" + $restoreErr).Contains((Get-ClmText "backup.restore.busy"))) "restauration juste apres une autre : attend son tour"

. (Join-Path $bin "claude-menu-archive.ps1")
Remove-Item -LiteralPath $script:LocksDl -Recurse -Force
