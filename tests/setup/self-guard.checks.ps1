. Import-ClmModule claude-self-guard
$guardRead = (Get-Item "function:Read-ClmStamp").ScriptBlock
$guardWait = $script:ClmInstallWaitMs
$guardReloaded = $script:ClmReloaded
$script:GuardStamps = New-Object Collections.Generic.Queue[string]
function Read-ClmStamp {
  param([string]$Dir = "")
  if ($script:GuardStamps.Count -gt 1) { return $script:GuardStamps.Dequeue() }
  return $script:GuardStamps.Peek()
}

try {
  $script:GuardStamps.Enqueue("v1")
  Assert-Equal "v1" (Wait-ClmInstall) "entree : rien en cours, marque rendue tout de suite"
  $script:GuardStamps.Clear()
  foreach ($s in @("installing", "installing", "v2")) { $script:GuardStamps.Enqueue($s) }
  Assert-Equal "v2" (Wait-ClmInstall) "entree : installation en cours attendue jusqu'au bout"
  $script:GuardStamps.Clear()
  $script:GuardStamps.Enqueue("installing")
  $script:ClmInstallWaitMs = 300
  $sw = [Diagnostics.Stopwatch]::StartNew()
  Assert-Equal "installing" (Wait-ClmInstall) "entree : attente bornee"
  Assert-True ($sw.ElapsedMilliseconds -lt 3000) "entree : attente bornee, rendue a temps"

  $script:GuardStamps.Clear()
  $script:GuardStamps.Enqueue("v2")
  $script:ClmReloaded = $false
  Assert-True (-not (Test-ClmReloadNeeded "v2")) "rechargement : rien n'a bouge"
  Assert-True (Test-ClmReloadNeeded "v1") "rechargement : version changee pendant le chargement"
  Assert-True (Test-ClmReloadNeeded "installing") "rechargement : charge pendant une installation"
  $script:ClmReloaded = $true
  Assert-True (-not (Test-ClmReloadNeeded "v1")) "rechargement : une seule fois"

  Assert-Equal "-1|--web|--updated" ((Get-ClmReloadArgs @("-1", "--web")) -join "|") "rechargement : memes arguments, sans nouvelle mise a jour"
  Assert-Equal "--updated|x" ((Get-ClmReloadArgs @("--updated", "x")) -join "|") "rechargement : drapeau deja la, pas en double"
  Assert-Equal "--updated" ((Get-ClmReloadArgs @()) -join "|") "rechargement : sans argument"
} finally {
  Set-Item "function:Read-ClmStamp" $guardRead
  $script:ClmInstallWaitMs = $guardWait
  $script:ClmReloaded = $guardReloaded
}
