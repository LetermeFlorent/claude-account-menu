$storeSaved = @($script:SyncKeyStorePath, $script:SyncKeyStoreOs)
$storeMocked = @("Invoke-SecurityBatch", "Read-KeychainItem", "Remove-KeychainItems")
$storeKept = @{}
foreach ($n in $storeMocked) { $storeKept[$n] = (Get-Item ("function:" + $n)).ScriptBlock }
$script:SyncKeyStorePath = Join-Path $script:Sandbox "sync-key-test"
$storeKeys = New-SyncKeys ([byte[]](5..36)) ([byte[]](1..16)) 600000
$storeMaster = [Convert]::ToBase64String($storeKeys.Master)
$script:FakeChain = @{}
function Invoke-SecurityBatch {
  param([string[]]$Lines)
  foreach ($l in $Lines) {
    if ($l -notmatch '-a "([^"]+)" -s "([^"]+)" -X "([0-9a-f]+)"') { continue }
    $hex = $Matches[3]
    $b = [byte[]](0..($hex.Length / 2 - 1) | ForEach-Object { [Convert]::ToByte($hex.Substring($_ * 2, 2), 16) })
    $script:FakeChain[$Matches[2] + "|" + $Matches[1]] = [Text.Encoding]::UTF8.GetString($b)
  }
}
function Read-KeychainItem { param([string]$Service, [string]$Account) return $script:FakeChain[$Service + "|" + $Account] }
function Remove-KeychainItems { param([string]$Service, [string[]]$Accounts) foreach ($a in $Accounts) { $script:FakeChain.Remove($Service + "|" + $a) } }
try {
  $script:SyncKeyStoreOs = "Linux"
  Assert-True (-not (Test-SyncKeyStored)) "cle de synchro : absente au depart"
  Assert-Throws { Get-SyncKeys } (Get-ClmText "sync.key.missing") "cle de synchro absente : synchro refusee"
  Save-SyncKeys $storeKeys
  Assert-True (Test-SyncKeyStored) "linux : cle enregistree"
  Assert-Equal $storeKeys.Check (Get-SyncKeys).Check "linux : cle relue"
  Assert-Equal 600000 (Get-SyncKeys).Iterations "linux : reglages de derivation gardes"
  if ($script:OsName -ne "Windows") { Assert-Equal "-rw-------" (Get-Item -LiteralPath $script:SyncKeyStorePath).UnixMode "linux : fichier en 600" }
  [IO.File]::WriteAllText($script:SyncKeyStorePath, ([IO.File]::ReadAllText($script:SyncKeyStorePath)).Replace($storeKeys.Check, ("0" * 64)))
  Assert-Throws { Get-SyncKeys } (Get-ClmText "sync.key.broken") "linux : cle abimee refusee"
  Remove-SyncKeys
  Assert-True (-not (Test-SyncKeyStored)) "linux : cle oubliee"

  $script:SyncKeyStoreOs = "MacOS"
  Save-SyncKeys $storeKeys
  Assert-True (-not (Test-Path -LiteralPath $script:SyncKeyStorePath)) "macos : rien dans un fichier"
  Assert-True ($script:FakeChain.Count -eq 1 -and $script:FakeChain.ContainsKey($script:SyncKeyService + "|" + $script:SyncKeyAccount)) "macos : cle dans le trousseau"
  Assert-Equal $storeKeys.Check (Get-SyncKeys).Check "macos : cle relue du trousseau"
  Remove-SyncKeys
  Assert-True (-not (Test-SyncKeyStored)) "macos : cle retiree du trousseau"

  if ($script:OsName -eq "Windows") {
    $script:SyncKeyStoreOs = "Windows"
    Save-SyncKeys $storeKeys
    Assert-True (-not ([IO.File]::ReadAllText($script:SyncKeyStorePath)).Contains($storeMaster)) "windows : cle protegee par DPAPI"
    Assert-Equal $storeKeys.Check (Get-SyncKeys).Check "windows : cle relue"
    Remove-SyncKeys
    Assert-True (-not (Test-SyncKeyStored)) "windows : cle oubliee"
  }
} finally {
  $script:SyncKeyStorePath, $script:SyncKeyStoreOs = $storeSaved
  foreach ($n in $storeMocked) { Set-Item -Path ("function:" + $n) -Value $storeKept[$n] }
}
