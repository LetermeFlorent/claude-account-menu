if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-platform.ps1")) { . (Join-Path $PSScriptRoot "claude-platform.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-json.ps1")) { . (Join-Path $PSScriptRoot "claude-json.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-state.ps1")) { . (Join-Path $PSScriptRoot "claude-state.ps1") }
$script:DisplayFileName = "display.json"
$script:DisplayPalettes = @("auto", "dark", "light")
$script:DisplayAnims = @("auto", "on", "off")
$script:DisplayAliases = @{ sombre = "dark"; clair = "light"; "1" = "on"; "0" = "off" }

function Get-DisplayPath {
  param($Vars = $null)
  return Get-StatePath $script:DisplayFileName $Vars
}

function ConvertTo-DisplayValue {
  param($Value, [string[]]$Allowed)
  $v = ("" + $Value).Trim().ToLowerInvariant()
  if ($script:DisplayAliases.ContainsKey($v)) { $v = $script:DisplayAliases[$v] }
  if ($Allowed -ccontains $v) { return $v }
  return $null
}

function Read-DisplayConfig {
  param($Vars = $null)
  $out = @{ palette = "auto"; anim = "auto" }
  try { $data = Read-JsonFile (Get-DisplayPath $Vars) } catch { return $out }
  if ($data -isnot [Collections.IDictionary]) { return $out }
  if (@($data.Keys) -contains "palette") { $p = ConvertTo-DisplayValue $data["palette"] $script:DisplayPalettes; if ($p) { $out.palette = $p } }
  if (@($data.Keys) -contains "anim") { $a = ConvertTo-DisplayValue $data["anim"] $script:DisplayAnims; if ($a) { $out.anim = $a } }
  return $out
}

function Save-DisplayConfig {
  param([string]$Palette, [string]$Anim, $Vars = $null)
  $p = ConvertTo-DisplayValue $Palette $script:DisplayPalettes
  if (-not $p) { throw ("couleurs inconnues : " + $Palette + ", choisir auto, dark ou light") }
  $a = ConvertTo-DisplayValue $Anim $script:DisplayAnims
  if (-not $a) { throw ("animations inconnues : " + $Anim + ", choisir auto, on ou off") }
  Write-TextFileAtomic (Get-DisplayPath $Vars) ((ConvertTo-JsonText ([ordered]@{ palette = $p; anim = $a })) + "`n")
  return @{ palette = $p; anim = $a }
}

function Set-DisplayPalette {
  param([string]$Palette, $Vars = $null)
  return Save-DisplayConfig $Palette (Read-DisplayConfig $Vars).anim $Vars
}

function Set-DisplayAnim {
  param([string]$Anim, $Vars = $null)
  return Save-DisplayConfig (Read-DisplayConfig $Vars).palette $Anim $Vars
}
