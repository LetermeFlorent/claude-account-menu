. Import-ClmModule claude-ui-contrast

$script:WtSchemeColors = @{
  "Campbell" = "#0C0C0C"; "Campbell Powershell" = "#012456"; "Vintage" = "#000000"
  "One Half Dark" = "#282C34"; "One Half Light" = "#FFFFFF"; "Solarized Dark" = "#002B36"
  "Solarized Light" = "#FDF6E3"; "Tango Dark" = "#000000"; "Tango Light" = "#FFFFFF"
  "Dark+" = "#1E1E1E"; "CGA" = "#000000"; "IBM 5153" = "#000000"; "Ottosson" = "#000000"
}
$script:WtSettingsPaths = @(
  "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
  "Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
  "Microsoft\Windows Terminal\settings.json"
)

function ConvertFrom-HexColor {
  param([string]$Hex)
  $m = [regex]::Match($Hex, '^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})$')
  if (-not $m.Success) { return $null }
  $digits = $m.Groups[1].Value
  if ($digits.Length -eq 3) { $digits = (($digits.ToCharArray() | ForEach-Object { "$_$_" }) -join "") }
  return ,@([Convert]::ToInt32($digits.Substring(0, 2), 16), [Convert]::ToInt32($digits.Substring(2, 2), 16), [Convert]::ToInt32($digits.Substring(4, 2), 16))
}

function Get-JsonProperty {
  param($Obj, [string]$Name)
  if ($null -eq $Obj) { return $null }
  $prop = $Obj.PSObject.Properties[$Name]
  if ($null -eq $prop) { return $null }
  if ($null -eq $prop.Value) { return $null }
  return ,$prop.Value
}

function Find-WtSettingsFile {
  param($Vars)
  $base = Read-EnvVar "LOCALAPPDATA" $Vars
  if ($base -eq "") { return "" }
  foreach ($rel in $script:WtSettingsPaths) {
    $path = Join-Path $base $rel
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
    if ((Get-Item -LiteralPath $path).Length -gt 1MB) { continue }
    return $path
  }
  return ""
}

function ConvertFrom-JsonWithComments {
  param([string]$Text)
  $str = '("(?:\\.|[^"\\])*")'
  $clean = [regex]::Replace($Text, $str + '|//[^\n]*|/\*[\s\S]*?\*/', '$1')
  $clean = [regex]::Replace($clean, $str + '|,(\s*[}\]])', '$1$2')
  return ($clean | ConvertFrom-Json)
}

function Get-WtProfileParts {
  param($Settings, [string]$ProfileId)
  $profiles = Get-JsonProperty $Settings "profiles"
  $defaults = $null
  $list = $profiles
  if ($profiles -isnot [array]) {
    $defaults = Get-JsonProperty $profiles "defaults"
    $list = Get-JsonProperty $profiles "list"
  }
  $wanted = $ProfileId
  if ($wanted -eq "") { $wanted = [string](Get-JsonProperty $Settings "defaultProfile") }
  $found = $null
  foreach ($item in @($list)) {
    if ([string](Get-JsonProperty $item "guid") -eq $wanted) { $found = $item; break }
  }
  return @($found, $defaults)
}

function Get-WtFirstValue {
  param($Sources, [string]$Name)
  foreach ($src in $Sources) {
    $value = Get-JsonProperty $src $Name
    if ($null -ne $value -and "$value" -ne "") { return $value }
  }
  return $null
}

function Get-WtSchemeColor {
  param($Settings, $Name)
  if ($Name -isnot [string]) { return $null }
  foreach ($scheme in (Get-JsonProperty $Settings "schemes")) {
    if ([string](Get-JsonProperty $scheme "name") -eq $Name) { return ConvertFrom-HexColor ([string](Get-JsonProperty $scheme "background")) }
  }
  if ($script:WtSchemeColors.ContainsKey($Name)) { return ConvertFrom-HexColor $script:WtSchemeColors[$Name] }
  return $null
}

function Get-WtBackground {
  param($Settings, [string]$ProfileId)
  $sources = @(Get-WtProfileParts $Settings $ProfileId)
  $direct = ConvertFrom-HexColor ([string](Get-WtFirstValue $sources "background"))
  if ($null -ne $direct) { return ,$direct }
  $name = Get-WtFirstValue $sources "colorScheme"
  if ($null -eq $name) { $name = "Campbell" }
  return ,(Get-WtSchemeColor $Settings $name)
}

function Get-WtTheme {
  param($Vars = $null)
  try {
    if ((Read-EnvVar "WT_SESSION" $Vars) -eq "") { return "" }
    $file = Find-WtSettingsFile $Vars
    if ($file -eq "") { return "" }
    $settings = ConvertFrom-JsonWithComments ([IO.File]::ReadAllText($file))
    $rgb = Get-WtBackground $settings (Read-EnvVar "WT_PROFILE_ID" $Vars)
    return (Get-BackgroundTheme $rgb)
  }
  catch { Write-Verbose $_.Exception.Message }
  return ""
}
