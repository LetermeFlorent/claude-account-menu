if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-state.ps1")) { . (Join-Path $PSScriptRoot "claude-state.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-file-io.ps1")) { . (Join-Path $PSScriptRoot "claude-file-io.ps1") }
$script:BackupKeyName = "backup-key"
$script:BackupMarksName = "backup-marks.txt"
$script:BackupMarksMax = 500
$script:BackupMarksWaitMs = 5000
$script:BackupKeyBytes = 32

function ConvertTo-LowerHex {
  param([byte[]]$Bytes)
  return [BitConverter]::ToString($Bytes).Replace("-", "").ToLowerInvariant()
}

function Get-BackupKey {
  $path = Get-StatePath $script:BackupKeyName
  if ([IO.File]::Exists($path)) {
    try { $key = [Convert]::FromBase64String(([IO.File]::ReadAllText($path)).Trim()) } catch [FormatException] { $key = @() }
    if ($key.Length -ge $script:BackupKeyBytes) { return ,$key }
  }
  $key = New-Object byte[] $script:BackupKeyBytes
  $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
  try { $rng.GetBytes($key) } finally { $rng.Dispose() }
  Write-TextFileAtomic $path ([Convert]::ToBase64String($key)) -Private
  return ,$key
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
  return @(foreach ($line in [IO.File]::ReadAllLines($path)) {
    $f = $line.Split("`t")
    if ($f.Count -eq 3) { [PSCustomObject]@{ Name = $f[0]; Size = $f[1]; Mac = $f[2] } }
  })
}

function Add-BackupMark {
  param([string]$Path)
  $info = [IO.FileInfo]$Path
  $line = $info.Name + "`t" + $info.Length + "`t" + (Get-BackupMac $Path)
  $marks = Get-StatePath $script:BackupMarksName
  Invoke-WithFileLock ($marks + ".lock") $script:BackupMarksWaitMs "liste des sauvegardes en cours d'ecriture" {
    $kept = @(Read-BackupMarks | Where-Object { $_.Name -cne $info.Name } | ForEach-Object { $_.Name + "`t" + $_.Size + "`t" + $_.Mac })
    $kept = @($kept | Select-Object -Last ($script:BackupMarksMax - 1)) + $line
    Write-TextFileAtomic $marks (($kept -join "`n") + "`n") -Private
  }
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
