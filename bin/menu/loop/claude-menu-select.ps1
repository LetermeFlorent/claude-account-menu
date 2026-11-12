if (-not (Test-Path Function:\Import-ClmModule)) { . (Join-Path $PSScriptRoot "../../claude-import.ps1") }
. Import-ClmModule claude-text
function Read-AccountNumber {
  param($Usages)
  $count = 0
  if ($null -ne $Usages) { $count = @($Usages).Count }
  if ($count -eq 0) {
    Write-Host ("  " + (Get-ClmText "menu.select.noAccount"))
    return $null
  }
  Clear-SettledInput
  $n = Read-Host (Get-ClmText "menu.select.number" @($count))
  if ($n -match "^[1-9]$" -and [int]$n -le $count) { return $Usages[[int]$n - 1].Acc }
  return $null
}
