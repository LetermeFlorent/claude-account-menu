. Import-ClmModule claude-state, claude-file-io, claude-backup-key
$script:BackupMarksName = "backup-marks.txt"
$script:BackupMarksMax = 500
$script:BackupMarksWaitMs = 120000

function ConvertTo-LowerHex {
  param([byte[]]$Bytes)
  return [BitConverter]::ToString($Bytes).Replace("-", "").ToLowerInvariant()
}

function Get-BackupMac {
  param([string]$Path)
  $info = [IO.FileInfo]$Path
  $sha = [Security.Cryptography.SHA256]::Create()
  $fs = [IO.File]::OpenRead($Path)
  try { $hash = ConvertTo-LowerHex ($sha.ComputeHash($fs)) } finally { $fs.Dispose(); $sha.Dispose() }
  $hmac = New-Object Security.Cryptography.HMACSHA256 (, (Get-BackupKey))
  try { return ConvertTo-LowerHex ($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($info.Name + "`n" + $info.Length + "`n" + $hash))) } finally { $hmac.Dispose() }
}

function Read-BackupMarks {
  $path = Get-StatePath $script:BackupMarksName
  if (-not [IO.File]::Exists($path)) { return @() }
  return @(foreach ($line in ((Read-SharedText $path) -split "`r?`n")) {
    $f = $line.Split("`t")
    if ($f.Count -eq 3) { [PSCustomObject]@{ Name = $f[0]; Size = $f[1]; Mac = $f[2] } }
  })
}

function Add-BackupMark {
  param([string]$Path)
  $info = [IO.FileInfo]$Path
  $line = $info.Name + "`t" + $info.Length + "`t" + (Get-BackupMac $Path)
  $marks = Get-StatePath $script:BackupMarksName
  $fs = Enter-FileLock ($marks + ".lock") $script:BackupMarksWaitMs
  try {
    $kept = @(Read-BackupMarks | Where-Object { $_.Name -cne $info.Name } | ForEach-Object { $_.Name + "`t" + $_.Size + "`t" + $_.Mac })
    $kept = @($kept | Select-Object -Last ($script:BackupMarksMax - 1)) + $line
    Write-TextFileAtomic $marks (($kept -join "`n") + "`n") -Private
  } finally { if ($null -ne $fs) { $fs.Dispose() } }
}

function Test-BackupListed {
  param([IO.FileInfo]$File)
  return @(Read-BackupMarks | Where-Object { $_.Name -ceq $File.Name -and $_.Size -eq [string]$File.Length }).Count -gt 0
}

function Test-BackupTrusted {
  param([string]$Path)
  if (-not [IO.File]::Exists($Path)) { return $false }
  $name = [IO.Path]::GetFileName($Path)
  $hits = @(Read-BackupMarks | Where-Object { $_.Name -ceq $name })
  if ($hits.Count -eq 0) { return $false }
  $mac = Get-BackupMac $Path
  return @($hits | Where-Object { $_.Mac -ceq $mac }).Count -gt 0
}
