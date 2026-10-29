. Import-ClmModule claude-accounts, claude-json, claude-text
$script:DefaultTheme = "dark"

function Repair-Onboarding {
  param($Acc)
  $path = Get-AccountConfigFile $Acc
  if (-not (Test-Path -LiteralPath $path) -or ([IO.FileInfo]$path).Length -eq 0) {
    Write-JsonFile $path ([ordered]@{ hasCompletedOnboarding = $true; lastOnboardingVersion = (Get-ClaudeVersion) })
    return $true
  }
  $cfg = Read-JsonFile $path
  if ($null -eq $cfg -or $cfg["hasCompletedOnboarding"] -eq $true) { return $false }
  $cfg["hasCompletedOnboarding"] = $true
  if (-not ($cfg.Keys -contains "lastOnboardingVersion")) { $cfg["lastOnboardingVersion"] = Get-ClaudeVersion }
  Write-JsonFile $path $cfg
  return $true
}

function Get-SettingsTheme {
  param($Acc)
  $data = Read-JsonFile (Join-Path (Get-AccountPath $Acc) "settings.json")
  if ($null -eq $data -or -not ($data.Keys -contains "theme")) { return "" }
  return [string]$data["theme"]
}

function Find-KnownTheme {
  param($Acc, $Accs)
  foreach ($a in $Accs) {
    if ($a.Dir -eq $Acc.Dir) { continue }
    try { $t = Get-SettingsTheme $a } catch { $t = "" }
    if ($t) { return $t }
  }
  return $script:DefaultTheme
}

function Repair-Theme {
  param($Acc, $Accs)
  $path = Join-Path (Get-AccountPath $Acc) "settings.json"
  $data = Read-JsonFile $path
  if ($null -eq $data -or ($data.Keys -contains "theme")) { return $false }
  $data["theme"] = Find-KnownTheme $Acc $Accs
  Write-JsonFile $path $data
  return $true
}

function Repair-AccountConfig {
  param($Acc)
  try {
    $null = Repair-Onboarding $Acc
    $null = Repair-Theme $Acc @(Get-Accounts)
  } catch { Write-Host ("  " + (Get-ClmText "accounts.guard.configError" @($_.Exception.Message))) -ForegroundColor DarkYellow }
}
