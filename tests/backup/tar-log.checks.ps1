$logPath = Join-Path $script:Sandbox "tar-log.incremental.log"
$reader = New-TarLogReader $logPath
Assert-Equal "" ((Read-TarLogLines $reader) -join "|") "journal tar : fichier absent, aucune ligne"
Assert-Equal 0 $reader.BytesRead "journal tar : fichier absent, aucun octet lu"

$appendLog = {
  param([string]$Path, [string]$Text)
  $stream = [IO.File]::Open($Path, "Append", "Write", "ReadWrite")
  $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($Text)
  $stream.Write($bytes, 0, $bytes.Length)
  $stream.Close()
}

& $appendLog $logPath "ab`r`ncd"
Assert-Equal "ab" ((Read-TarLogLines $reader) -join "|") "journal tar : ligne incomplete gardee en attente"
& $appendLog $logPath "ef`r`n`r`ngh`n"
Assert-Equal "cdef|gh" ((Read-TarLogLines $reader) -join "|") "journal tar : ligne coupee entre deux ajouts, lignes vides ignorees"
Assert-Equal "" ((Read-TarLogLines $reader) -join "|") "journal tar : rien de neuf, rien de relu"
& $appendLog $logPath ("caf" + [string][char]0xE9 + "`n")
Assert-Equal ("caf" + [string][char]0xE9) ((Read-TarLogLines $reader) -join "|") "journal tar : accent lu en UTF-8"
Assert-Equal ([IO.FileInfo]$logPath).Length $reader.BytesRead "journal tar : chaque octet lu une seule fois"

$splitPath = Join-Path $script:Sandbox "tar-log.split.log"
$splitReader = New-TarLogReader $splitPath
$accent = (New-Object Text.UTF8Encoding($false)).GetBytes([string][char]0xE9)
$stream = [IO.File]::Open($splitPath, "Create", "Write", "ReadWrite")
$stream.Write($accent, 0, 1)
$stream.Flush()
Assert-Equal "" ((Read-TarLogLines $splitReader) -join "|") "journal tar : caractere coupe en deux, rien rendu"
$stream.Write($accent, 1, 1)
$stream.Write([byte[]]@(10), 0, 1)
$stream.Close()
Assert-Equal ([string][char]0xE9) ((Read-TarLogLines $splitReader) -join "|") "journal tar : caractere coupe en deux, rendu entier"

$origWaitProgress = (Get-Item Function:\Wait-Progress).ScriptBlock
$origWriteTarProgress = (Get-Item Function:\Write-TarProgress).ScriptBlock
$origNewReader = (Get-Item Function:\New-TarLogReader).ScriptBlock
$origSizes = $script:Sizes
try {
  $script:WaitOut = Join-Path $script:Sandbox "wait.out.log"
  $script:WaitErr = Join-Path $script:Sandbox "wait.err.log"
  $script:WaitAppend = $appendLog
  $script:WaitPolls = 0
  $script:WaitPcts = New-Object 'System.Collections.Generic.List[int]'
  $script:WaitReaders = New-Object 'System.Collections.Generic.List[object]'
  $script:Sizes = @{ "a" = 10; "b" = 10; "c" = 10; "d" = 10 }
  function Wait-Progress {
    param([int]$Ms)
    $script:WaitPolls++
    if ($script:WaitPolls -eq 1) { & $script:WaitAppend $script:WaitOut "a`r`nb" }
    if ($script:WaitPolls -eq 2) { & $script:WaitAppend $script:WaitOut "`r`nc`r`n" }
    if ($script:WaitPolls -eq 3) { & $script:WaitAppend $script:WaitErr "a d`r`ntar: avertissement`r`n" }
  }
  function Write-TarProgress {
    param([string]$Label, [int]$Pct)
    $script:WaitPcts.Add($Pct)
  }
  function New-TarLogReader {
    param([string]$Path)
    $r = & $origNewReader $Path
    $script:WaitReaders.Add($r)
    return $r
  }
  $fakeProc = New-Object PSObject
  $fakeProc | Add-Member ScriptProperty HasExited { $script:WaitPolls -ge 3 }
  Wait-Tar $fakeProc $script:WaitOut $script:WaitErr 40 "test"
  Assert-Equal "25|75|99|100" ($script:WaitPcts -join "|") "attente tar : pourcentages rendus"
  $bytesRead = [long]0
  foreach ($r in $script:WaitReaders) { $bytesRead += $r.BytesRead }
  $expected = ([IO.FileInfo]$script:WaitOut).Length + ([IO.FileInfo]$script:WaitErr).Length
  Assert-Equal $expected $bytesRead "attente tar : chaque octet des deux journaux lu une seule fois"
} finally {
  Set-Item Function:\Wait-Progress $origWaitProgress
  Set-Item Function:\Write-TarProgress $origWriteTarProgress
  Set-Item Function:\New-TarLogReader $origNewReader
  $script:Sizes = $origSizes
}
