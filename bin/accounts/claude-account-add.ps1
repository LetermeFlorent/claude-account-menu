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
  Clear-ConsoleScreen
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
  if (Test-DuplicateAccountEmail $acc) {
    Clear-AccountLogin $acc
    Save-Registry @(Get-Accounts | Where-Object { $_.Dir -ne $acc.Dir })
    $dir = Get-AccountPath $acc
    if (Test-Path -LiteralPath $dir) { Remove-LinkOrTree $dir }
    throw (Get-ClmText "accounts.add.duplicate" @($mail))
  }
  return Get-ClmText "accounts.add.done" @($acc.Label, $mail)
}

function Remove-LinkOrTree {
  param([string]$Path)
  $item = Get-Item -LiteralPath $Path -Force
  if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    if ($script:OsName -eq "Windows" -and $item.PSIsContainer) { [IO.Directory]::Delete($item.FullName, $false) }
    else { [IO.File]::Delete($item.FullName) }
    return
  }
  if ($item.PSIsContainer) {
    foreach ($c in @(Get-ChildItem -LiteralPath $item.FullName -Force)) { Remove-LinkOrTree $c.FullName }
    [IO.Directory]::Delete($item.FullName, $false)
    return
  }
  try { [IO.File]::Delete($item.FullName); return } catch [UnauthorizedAccessException] { Write-Verbose $_.Exception.Message }
  $item.Attributes = [IO.FileAttributes]::Normal
  [IO.File]::Delete($item.FullName)
}
