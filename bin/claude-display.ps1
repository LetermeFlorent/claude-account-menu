. Import-ClmModule claude-display-config, claude-text
$script:DisplayRefusals = @{ palette = "ui.display.badPalette"; anim = "ui.display.badAnim"; lang = "ui.display.badLang"; webTheme = "ui.display.badWebTheme" }

function Set-DisplayValues {
  param($Values, $Vars = $null)
  $choices = Get-DisplayChoices
  $clean = [ordered]@{}
  foreach ($k in @($Values.Keys)) {
    if (-not $choices.Contains($k)) { throw (Get-ClmText "ui.display.badKey" $k) }
    $v = ConvertTo-DisplayValue $Values[$k] $choices[$k]
    if (-not $v) { throw (Get-ClmText $script:DisplayRefusals[$k] $Values[$k]) }
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
