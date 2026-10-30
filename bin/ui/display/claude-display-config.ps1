. Import-ClmModule claude-platform, claude-json, claude-state
$script:DisplayFileName = "display.json"
$script:DisplayPalettes = @("auto", "dark", "light")
$script:DisplayAnims = @("auto", "on", "off")
$script:DisplayLangs = @("auto", "en", "fr")
$script:DisplayWebThemes = @("system", "light", "dark")
$script:DisplayAliases = @{ sombre = "dark"; clair = "light"; "1" = "on"; "0" = "off" }

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
