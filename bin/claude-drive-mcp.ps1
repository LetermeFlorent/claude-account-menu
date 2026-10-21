. (Join-Path $PSScriptRoot "claude-mcp-projects.ps1")
. (Join-Path $PSScriptRoot "claude-drive-skills.ps1")
$script:PcFileExt = ".json"
$script:PcFileMax = 1048576
$script:ErasedKeepMs = [long]30 * 24 * 3600 * 1000
$script:McpPerPc = $false

function Read-PcFile {
  param([string]$Id)
  $text = Get-DriveText $Id
  if ($text.Length -gt $script:PcFileMax) { return New-PcContent }
  try { $data = ConvertFrom-JsonText $text } catch { $data = $null }
  return ConvertFrom-PcData $data $false
}

function Update-PcFiles {
  param($Catalog, $Presence)
  $seen = New-PathMap
  foreach ($name in $Presence.Keys) {
    if (-not $name.EndsWith($script:PcFileExt, [StringComparison]::Ordinal)) { continue }
    $pc = $name.Substring(0, $name.Length - $script:PcFileExt.Length)
    $md5 = [string]$Presence[$name].Md5
    $seen[$pc] = $true
    $old = $Catalog.Pcs[$pc]
    if ($null -ne $old -and $md5 -and $old.Md5 -eq $md5) { continue }
    $c = Read-PcFile $Presence[$name].Id
    $c.Md5 = $md5
    $Catalog.Pcs[$pc] = $c
  }
  foreach ($pc in @($Catalog.Pcs.Keys)) { if (-not $seen.ContainsKey($pc)) { $Catalog.Pcs.Remove($pc) } }
}

function Get-OwnPcContent {
  param($Catalog, [string]$Pc)
  if ($null -eq $Catalog.Pcs[$Pc]) { $Catalog.Pcs[$Pc] = New-PcContent }
  return $Catalog.Pcs[$Pc]
}

function Get-OwnPcText {
  param($Catalog, [string]$Pc)
  return ConvertTo-JsonText (ConvertTo-PcData (Get-OwnPcContent $Catalog $Pc))
}

function Get-NextAt {
  param($Pcs, [string]$Key)
  $at = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  foreach ($pc in $Pcs.Keys) {
    $e = $Pcs[$pc].Mcp[$Key]
    if ($null -ne $e -and $e.At -ge $at) { $at = $e.At + 1 }
  }
  return $at
}

function Publish-McpEntry {
  param($Catalog, [string]$Pc, [string]$Key, [string]$Def)
  $cur = (Get-McpCatalog $Catalog.Pcs)[$Key]
  if ($null -ne $cur -and $cur.Def -ceq $Def) { return }
  $os = $script:OsName
  if ($null -ne $cur) { $os = $cur.Os }
  $entry = @{ At = (Get-NextAt $Catalog.Pcs $Key); Deleted = $false; Os = $os; Def = $Def }
  (Get-OwnPcContent $Catalog $Pc).Mcp[$Key] = $entry
}

function Remove-McpEverywhere {
  param($Catalog, [string]$Pc, [string]$Key)
  if (-not (Test-McpKey $Key)) { return }
  $entry = @{ At = (Get-NextAt $Catalog.Pcs $Key); Deleted = $true; Os = ""; Def = "" }
  (Get-OwnPcContent $Catalog $Pc).Mcp[$Key] = $entry
}

function Add-ErasedSkills {
  param($Catalog, [string]$Pc, [string[]]$Names)
  $now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  $own = Get-OwnPcContent $Catalog $Pc
  foreach ($n in $Names) { if (Test-SkillName $n) { $own.Erased[$n] = $now } }
  foreach ($n in @($own.Erased.Keys)) { if ($now - $own.Erased[$n] -gt $script:ErasedKeepMs) { $own.Erased.Remove($n) } }
}

function Save-OwnPcFile {
  param($Prefs, [string]$Before)
  $text = Get-OwnPcText $Prefs.Catalog $Prefs.Pc
  if ($text -ceq $Before) { return }
  $name = $Prefs.Pc + $script:PcFileExt
  $id = ""
  if ($null -ne $Prefs.Presence[$name]) { $id = [string]$Prefs.Presence[$name].Id }
  $props = @{ $script:SyncFormatKey = ("" + $script:SyncFormat) }
  $r = Send-DriveText $Prefs.Folders.Presence $name $text $props $id
  (Get-OwnPcContent $Prefs.Catalog $Prefs.Pc).Md5 = [string]$r.Md5
}
