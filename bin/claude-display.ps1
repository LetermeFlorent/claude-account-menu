. Import-ClmModule claude-platform, claude-json, claude-state
$script:DisplayFileName = "display.json"
$script:DisplayPalettes = @("auto", "dark", "light")
$script:DisplayAnims = @("auto", "on", "off")
$script:DisplayLangs = @("auto", "en", "fr")
$script:DisplayWebThemes = @("system", "light", "dark")
$script:DisplayAliases = @{ sombre = "dark"; clair = "light"; "1" = "on"; "0" = "off" }
$script:DisplayRefusals = @{
  palette = "couleurs inconnues : {0}, choisir auto, dark ou light"; anim = "animations inconnues : {0}, choisir auto, on ou off"
  lang = "langue inconnue : {0}, choisir auto, en ou fr"; webTheme = "theme de la page inconnu : {0}, choisir system, light ou dark"
}

function Get-DisplayPath {
  param($Vars = $null)
  return Get-StatePath $script:DisplayFileName $Vars
}

function Get-DisplayChoices {
  return [ordered]@{ palette = $script:DisplayPalettes; anim = $script:DisplayAnims; lang = $script:DisplayLangs; webTheme = $script:DisplayWebThemes }
}

function ConvertTo-DisplayValue {
  param($Value, [string[]]$Allowed)
  $v = ("" + $Value).Trim().ToLowerInvariant()
  if ($script:DisplayAliases.ContainsKey($v)) { $v = $script:DisplayAliases[$v] }
  if ($Allowed -ccontains $v) { return $v }
  return $null
}

function Read-DisplayFile {
  param($Vars = $null)
  try { $data = Read-JsonFile (Get-DisplayPath $Vars) } catch { $data = $null }
  $out = [ordered]@{}
  if ($data -isnot [Collections.IDictionary]) { return $out }
  foreach ($k in @($data.Keys)) { $out[[string]$k] = $data[$k] }
  return $out
}

function Read-DisplayConfig {
  param($Vars = $null)
  $choices = Get-DisplayChoices
  $data = Read-DisplayFile $Vars
  $out = @{}
  foreach ($k in $choices.Keys) {
    $out[$k] = $choices[$k][0]
    if (-not $data.Contains($k)) { continue }
    $v = ConvertTo-DisplayValue $data[$k] $choices[$k]
    if ($v) { $out[$k] = $v }
  }
  return $out
}

function Set-DisplayValues {
  param($Values, $Vars = $null)
  $choices = Get-DisplayChoices
  $clean = [ordered]@{}
  foreach ($k in @($Values.Keys)) {
    if (-not $choices.Contains($k)) { throw ("reglage d'affichage inconnu : " + $k) }
    $v = ConvertTo-DisplayValue $Values[$k] $choices[$k]
    if (-not $v) { throw ($script:DisplayRefusals[$k] -f $Values[$k]) }
    $clean[$k] = $v
  }
  $data = Read-DisplayFile $Vars
  foreach ($k in $clean.Keys) { $data[$k] = $clean[$k] }
  Write-TextFileAtomic (Get-DisplayPath $Vars) ((ConvertTo-JsonText $data) + "`n")
  return Read-DisplayConfig $Vars
}

function Save-DisplayConfig {
  param([string]$Palette, [string]$Anim, $Vars = $null)
  return Set-DisplayValues ([ordered]@{ palette = $Palette; anim = $Anim }) $Vars
}

function Set-DisplayPalette {
  param([string]$Palette, $Vars = $null)
  return Set-DisplayValues @{ palette = $Palette } $Vars
}

function Set-DisplayAnim {
  param([string]$Anim, $Vars = $null)
  return Set-DisplayValues @{ anim = $Anim } $Vars
}
