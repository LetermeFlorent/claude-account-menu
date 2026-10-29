$slState = Get-StatusStatePath
$slLock = $slState + ".lock"
New-Item -ItemType Directory -Force -Path (Split-Path $slState) | Out-Null

$slHeld = Open-StatusStateLock $slState 0
Assert-True ($null -ne $slHeld) "verrou de la barre libre : pris"
Assert-Null (Open-StatusStateLock $slState 0) "verrou de la barre deja tenu : refuse a un second preneur"
if ($script:OsName -eq "Windows") {
  $slOpen = $null
  try { $slOpen = [IO.File]::Open($slLock, "OpenOrCreate", "ReadWrite", "ReadWrite, Delete") } catch { Write-Verbose $_.Exception.Message }
  Assert-True ($null -ne $slOpen) "verrou de la barre tenu par clm : la barre peut encore ouvrir le fichier"
  if ($null -ne $slOpen) { $slOpen.Dispose() }
}
Close-StatusStateLock $slHeld
$slAgain = Open-StatusStateLock $slState 0
Assert-True ($null -ne $slAgain) "verrou de la barre rendu : repris"
Close-StatusStateLock $slAgain
Assert-True ([IO.File]::Exists($slLock)) "verrou de la barre rendu : fichier garde"

if ($script:OsName -ne "Windows") {
  $slTools = $script:StatusLockTools
  $script:StatusLockTools = @("clm-no-such-tool")
  Assert-Null (Open-StatusStateLock $slState 0) "sans outil de verrou : pas de verrou, repli sur les changements"
  if (Get-Command perl -CommandType Application -ErrorAction SilentlyContinue) {
    $script:StatusLockTools = @("perl")
    $slPerl = Open-StatusStateLock $slState 0
    Assert-True ($null -ne $slPerl) "verrou de la barre par perl : pris"
    $script:StatusLockTools = $slTools
    Assert-Null (Open-StatusStateLock $slState 0) "verrou de la barre tenu par perl : refuse a un second preneur"
    Close-StatusStateLock $slPerl
  }
  $script:StatusLockTools = $slTools
}
