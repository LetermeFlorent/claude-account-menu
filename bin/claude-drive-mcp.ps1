. Import-ClmModule claude-mcp-projects, claude-drive-skills, claude-drive-sealed
$script:PcFileExt = ".json"
$script:PcFileArea = "presence/"
$script:PcFileMax = 1048576
$script:ErasedKeepMs = [long]30 * 24 * 3600 * 1000
$script:McpPerPc = $false

function Read-PcFile {
  param([string]$Id, [string]$Seal, $Keys)
  $text = Get-SealedText $Id $Seal $Keys
  if ($text.Length -gt $script:PcFileMax) { return $null }
  try { $data = ConvertFrom-JsonText $text } catch { $data = $null }
  if ($data -isnot [Collections.IDictionary]) { return $null }
  return ConvertFrom-PcData $data $false
}

function Update-PcFiles {
  param($Catalog, $Presence, $Keys, $Res)
  $seen = New-PathMap
  foreach ($name in $Presence.Keys) {
    if (-not $name.EndsWith($script:PcFileExt, [StringComparison]::Ordinal)) { continue }
    $pc = $name.Substring(0, $name.Length - $script:PcFileExt.Length)
    $md5 = [string]$Presence[$name].Md5
    $seen[$pc] = $true
    $old = $Catalog.Pcs[$pc]
    if ($null -ne $old -and $md5 -and $old.Md5 -eq $md5) { continue }
    if ([string]$Presence[$name].Props["k"] -ne $Keys.Id) {
      if ($null -eq $old) { $Catalog.Pcs[$pc] = New-PcContent }
      continue
    }
    try { $c = Read-PcFile $Presence[$name].Id ($script:PcFileArea + $name) $Keys }
    catch {
      if (-not (Test-SealRefusal $_) -or $null -eq $Res) { throw }
      $Res.Failed++; $Res.Refused.Add($script:PcFileArea + $name); continue
    }
    if ($null -eq $c) { continue }
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
  $name = $Prefs.Pc + $script:PcFileExt
  $own = $Prefs.Presence[$name]
  $sameKey = $null -ne $own -and $null -ne $own.Props -and [string]$own.Props["k"] -eq $Prefs.Keys.Id
  if ($text -ceq $Before -and $sameKey) { return }
  $id = ""
  if ($null -ne $own) { $id = [string]$own.Id }
  $props = @{ $script:SyncFormatKey = ("" + $script:SyncFormat); k = $Prefs.Keys.Id }
  $r = Send-SealedText @{ FolderId = $Prefs.Folders.Presence; Name = $name; Seal = ($script:PcFileArea + $name); Text = $text; Props = $props; Id = $id; Keys = $Prefs.Keys }
  if ($null -ne $own -and $null -ne $own.Props) { $own.Props["k"] = $Prefs.Keys.Id }
  (Get-OwnPcContent $Prefs.Catalog $Prefs.Pc).Md5 = [string]$r.Md5
  $Prefs.Sent = $text
}
