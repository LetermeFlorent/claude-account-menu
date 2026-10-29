$ioDir = Join-Path $script:Sandbox "file-io"
New-Item -ItemType Directory -Path $ioDir -Force | Out-Null
$target = Join-Path $ioDir "a.json"
Write-TextFileAtomic $target "un"
Assert-Equal "un" ([IO.File]::ReadAllText($target)) "ecriture atomique : nouveau fichier"
Write-TextFileAtomic $target "deux"
Assert-Equal "deux" ([IO.File]::ReadAllText($target)) "ecriture atomique : fichier remplace"
Assert-Equal 0 @(Get-ChildItem -LiteralPath $ioDir -Filter "*.tmp").Count "ecriture atomique : aucun temporaire laisse"
Assert-True (-not ([IO.File]::ReadAllBytes($target)[0] -eq 0xEF)) "ecriture atomique : sans BOM"

$asDir = Join-Path $ioDir "dossier"
New-Item -ItemType Directory -Path $asDir -Force | Out-Null
$threw = $false
try { Write-TextFileAtomic $asDir "x" } catch { $threw = $true }
Assert-True $threw "ecriture atomique : remplacement impossible, erreur dite"
Assert-Equal 0 @(Get-ChildItem -LiteralPath $ioDir -Filter "*.tmp").Count "ecriture atomique : temporaire retire apres un echec"

function Get-PrivateWriteTrace {
  param([scriptblock]$Write)
  $savedOs = $script:OsName
  $script:OsName = "Linux"
  $script:ChmodLog = New-Object 'System.Collections.Generic.List[string]'
  function chmod { $script:ChmodLog.Add((@($args) -join " ") + " taille " + ([IO.FileInfo]$args[1]).Length) }
  try { & $Write } finally { $script:OsName = $savedOs; Remove-Item Function:\chmod }
  return ,@($script:ChmodLog)
}

$trace = Get-PrivateWriteTrace { Write-TextFileAtomic $target "secret" -Private; Write-TextFileAtomic $target "public" }
Assert-Equal 1 $trace.Count "fichier prive : droits poses une seule fois"
Assert-True ($trace[0].StartsWith("600 ") -and $trace[0].EndsWith(" taille 0")) "fichier prive : droits poses avant le contenu"
Assert-Equal "public" ([IO.File]::ReadAllText($target)) "fichier prive : contenu ecrit"

$savedCredAcc = $script:HomeDir
$script:HomeDir = $ioDir
$credFile = Join-Path $ioDir "cred.json"
$trace = Get-PrivateWriteTrace { Write-CredentialFile $credFile ([PSCustomObject]@{ claudeAiOauth = [PSCustomObject]@{ accessToken = "t" } }) }
$script:HomeDir = $savedCredAcc
Assert-True ($trace.Count -eq 1 -and $trace[0].EndsWith(" taille 0")) "jeton local : droits poses avant le contenu"
Assert-True ([IO.File]::ReadAllText($credFile).Contains('"accessToken":"t"')) "jeton local : contenu ecrit"

$savedConfigPath = $script:DriveConfigPath
$script:DriveConfigPath = Join-Path $ioDir "drive.json"
$trace = Get-PrivateWriteTrace { Save-DriveConfig @{ refreshToken = "r" } }
$script:DriveConfigPath = $savedConfigPath
Assert-True ($trace.Count -eq 1 -and $trace[0].EndsWith(" taille 0")) "config Drive : droits poses avant le contenu"

$savedCatalogPath = $script:SyncCatalogPath
$script:SyncCatalogPath = Join-Path $ioDir "catalog.json"
$trace = Get-PrivateWriteTrace { Save-SyncCatalog (New-SyncCatalog) }
$script:SyncCatalogPath = $savedCatalogPath
Assert-True ($trace.Count -eq 1 -and $trace[0].EndsWith(" taille 0")) "catalogue de synchro : droits poses avant le contenu"
Assert-Equal 0 @(Get-ChildItem -LiteralPath $ioDir -Filter "*.tmp").Count "ecritures privees : aucun temporaire laisse"

$lockPath = Join-Path $ioDir "x.lock"
$script:LockRan = 0
Invoke-WithFileLock $lockPath 100 "occupe" { $script:LockRan++ }
Invoke-WithFileLock $lockPath 100 "occupe" { $script:LockRan++ }
Assert-Equal 2 $script:LockRan "verrou : libere a la fin de l'action"
$script:LockMsg = ""
$script:LockInner = $null
Invoke-WithFileLock $lockPath 100 "occupe" {
  $script:LockInner = Enter-FileLock $lockPath 250
  try { Invoke-WithFileLock $lockPath 250 "occupe" { $script:LockRan++ } } catch { $script:LockMsg = $_.Exception.Message }
}
Assert-Null $script:LockInner "verrou tenu : attente sans reussite rend null"
Assert-Equal "occupe" $script:LockMsg "verrou tenu : message dit"
Assert-Equal 2 $script:LockRan "verrou tenu : action non lancee"
$thrown = ""
try { Invoke-WithFileLock $lockPath 100 "occupe" { throw "dans l'action" } } catch { $thrown = $_.Exception.Message }
Assert-Equal "dans l'action" $thrown "verrou : erreur de l'action rendue"
$again = Enter-FileLock $lockPath 100
Assert-True ($null -ne $again) "verrou : libere apres une erreur"
$again.Dispose()

$savedCachePath = $script:UsageCachePath
$savedCacheWait = $script:UsageCacheLockMs
$script:UsageCachePath = Join-Path (Join-Path $ioDir "cache") "usage.json"
$script:UsageCacheLockMs = 100
Save-UsageEntry "un" ([PSCustomObject]@{ Pct5 = 1; Reset5 = $null; Pct7 = 2; Reset7 = $null })
Assert-Equal 1 (Read-UsageCache)["un"].Pct5 "cache d'usage : entree ecrite dans un dossier neuf"
$cacheLock = Enter-FileLock ($script:UsageCachePath + ".lock") 100
Save-UsageEntry "deux" ([PSCustomObject]@{ Pct5 = 3; Reset5 = $null; Pct7 = 4; Reset7 = $null })
$cacheLock.Dispose()
Assert-True (-not (Read-UsageCache).ContainsKey("deux")) "cache d'usage : pas d'ecriture pendant qu'un autre la tient"
Rename-UsageEntry "un" "trois"
Assert-True ((Read-UsageCache).ContainsKey("trois") -and -not (Read-UsageCache).ContainsKey("un")) "cache d'usage : entree renommee"
$script:UsageCachePath = $savedCachePath
$script:UsageCacheLockMs = $savedCacheWait

$lockMissing = Join-Path (Join-Path $ioDir "absent") "m.lock"
$lockClock = [Diagnostics.Stopwatch]::StartNew()
$lockMissed = Enter-FileLock $lockMissing 3000
$lockClock.Stop()
Assert-Null $lockMissed "verrou : dossier absent rend null"
Assert-True ($lockClock.ElapsedMilliseconds -lt 1000) "verrou : dossier absent sans attendre"

$lockUnder = Join-Path $ioDir "a.json"
$lockClock = [Diagnostics.Stopwatch]::StartNew()
$lockBlocked = Enter-FileLock (Join-Path $lockUnder "m.lock") 3000
$lockClock.Stop()
Assert-Null $lockBlocked "verrou : parent qui est un fichier rend null"
Assert-True ($lockClock.ElapsedMilliseconds -lt 1000) "verrou : parent qui est un fichier sans attendre"

$lockHeld = Enter-FileLock $lockPath 100
$lockClock = [Diagnostics.Stopwatch]::StartNew()
$lockSecond = Enter-FileLock $lockPath 300
$lockClock.Stop()
$lockHeld.Dispose()
Assert-Null $lockSecond "verrou tenu : deuxieme prise rend null"
Assert-True ($lockClock.ElapsedMilliseconds -ge 250) "verrou tenu : toujours vu comme occupe pendant l'attente"
