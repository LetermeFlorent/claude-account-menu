. Import-ClmModule claude-json, claude-text
function New-AccountSlot {
  param([string]$Label)
  $list = @(Get-Accounts)
  $n = $list.Count + 1
  while (Test-Path -LiteralPath (Join-Path $script:HomeDir (".claude-compte" + $n))) { $n++ }
  $Label = ConvertTo-AccountLabel $Label
  if ($Label -eq "") { $Label = "compte" + $n }
  $acc = [PSCustomObject]@{ Label = $Label; Dir = ".claude-compte" + $n }
  Repair-SharedLinks $acc
  $dir = Get-AccountPath $acc
  $settings = [IO.Path]::Combine($script:HomeDir, ".claude", "settings.json")
  if (Test-Path -LiteralPath $settings) { Copy-Item -LiteralPath $settings -Destination $dir }
  Write-JsonFile (Get-AccountConfigFile $acc) ([ordered]@{ hasCompletedOnboarding = $true; lastOnboardingVersion = (Get-ClaudeVersion) })
  Save-Registry ($list + $acc)
  return $acc
}

function Show-AddAccountHelp {
  Clear-Host
  Write-Host ""
  Write-Host ("  " + (Get-ClmText "accounts.add.title"))
  Write-Host ("  " + (Get-ClmText "accounts.add.browser")) -ForegroundColor DarkGray
  Write-Host ("  " + (Get-ClmText "accounts.add.signedInElsewhere")) -ForegroundColor DarkGray
  Write-Host ("  " + (Get-ClmText "accounts.add.privateWindow")) -ForegroundColor DarkGray
  Write-Host ""
}

function Add-Account {
  param($Label = $null)
  Show-AddAccountHelp
  if ($null -ne $Label) { return Connect-NewAccount $Label }
  $label = Read-Host ("  " + (Get-ClmText "accounts.add.namePrompt"))
  if ($label -eq "q") { return Get-ClmText "accounts.add.cancelled" }
  return Connect-NewAccount $label
}

function Connect-NewAccount {
  param([string]$Label)
  $acc = New-AccountSlot $Label
  Invoke-AsAccount $acc @("auth", "login") | Out-Host
  $mail = Get-AccountEmail $acc
  if ($mail -eq "") { return Get-ClmText "accounts.add.notSignedIn" @($acc.Label) }
  return Get-ClmText "accounts.add.done" @($acc.Label, $mail)
}
