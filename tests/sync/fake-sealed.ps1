function Get-FakeEntry {
  param([string]$Rel)
  $e = $script:Fake[$script:SealedPrefix + $Rel]
  if ($null -ne $e) { return $e }
  return $script:Fake[$Rel]
}

function Get-FakeText {
  param([string]$Rel)
  $e = $script:Fake[$script:SealedPrefix + $Rel]
  if ($null -ne $e) { return [Text.Encoding]::UTF8.GetString((Unprotect-SyncBytes $script:TestSyncKeys ($script:SealedFilesArea + $Rel) $e.Bytes)) }
  return [Text.Encoding]::UTF8.GetString($script:Fake[$Rel].Bytes)
}

function Add-FakeSealed {
  param([string]$Rel, [string]$Id, [string]$Text, [long]$M = 1700000000, [string]$Pc = "PCB", $Keys = $script:TestSyncKeys)
  $b = [Text.Encoding]::UTF8.GetBytes($Text)
  $props = @{ m = ("" + $M); pc = $Pc; h = (Protect-ContentMd5 $Keys (Get-FakeMd5 $b)); k = $Keys.Id }
  $name = $script:SealedPrefix + $Rel
  $script:Fake[$name] = @{ Id = $Id; Name = $name; Md5 = $props.h; M = $M; Pc = $Pc; Exp = 0; Props = $props; Bytes = (Protect-SyncBytes $Keys ($script:SealedFilesArea + $Rel) $b) }
}

function Test-FakeFile {
  param([string]$Rel)
  return $null -ne (Get-FakeEntry $Rel)
}

function Remove-FakeFile {
  param([string]$Rel)
  $script:Fake.Remove($script:SealedPrefix + $Rel)
  $script:Fake.Remove($Rel)
}

function Get-FakeRels {
  return [string[]]@($script:Fake.Keys | ForEach-Object { if ($_.StartsWith($script:SealedPrefix)) { $_.Substring($script:SealedPrefix.Length) } else { $_ } })
}

function Get-FakePcText {
  param([string]$Name)
  return [Text.Encoding]::UTF8.GetString((Unprotect-SyncBytes $script:TestSyncKeys ($script:PcFileArea + $Name) $script:FakePresence[$Name].Bytes))
}

function Set-FakePcText {
  param([string]$Name, [string]$Text)
  $script:FakePresence[$Name].Bytes = Protect-SyncBytes $script:TestSyncKeys ($script:PcFileArea + $Name) ([Text.Encoding]::UTF8.GetBytes($Text))
}

function Send-FakeSealedPc {
  param([string]$Name, [string]$Text)
  $props = @{ fmt = ("" + $script:SyncFormat); k = $script:TestSyncKeys.Id }
  return Send-FakePresence $Name (Protect-SyncBytes $script:TestSyncKeys ($script:PcFileArea + $Name) ([Text.Encoding]::UTF8.GetBytes($Text))) $props
}
