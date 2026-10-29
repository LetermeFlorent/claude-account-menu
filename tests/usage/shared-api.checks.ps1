$apiAcc = [PSCustomObject]@{ Label = "appel"; Dir = ".claude-appel" }
$apiState = Get-StatusStatePath
$apiDisplay = Get-DisplayPath
$apiFuture = [DateTimeOffset]::UtcNow.AddHours(3).ToString("o")
$apiFiles = @{}
foreach ($p in @($script:UsageCachePath, $apiState, $apiDisplay)) { if (Test-Path -LiteralPath $p) { $apiFiles[$p] = [IO.File]::ReadAllBytes($p) } }
$apiKept = @{}
foreach ($n in @("Invoke-UsageApi", "Read-AccountCredential")) {
  $f = Get-Item ("function:" + $n) -ErrorAction SilentlyContinue
  if ($null -ne $f) { $apiKept[$n] = $f.ScriptBlock }
}
$apiLockWait = $script:UsageLockWaitMs
$script:UsageApiCalls = 0
$script:UsageApiRefuse = $false

function Invoke-UsageApi {
  param([string]$Token)
  $script:UsageApiCalls++
  if ($script:UsageApiRefuse) {
    $e = New-Object Exception "trop de requetes"
    Add-Member -InputObject $e -NotePropertyName Response -NotePropertyValue ([PSCustomObject]@{ StatusCode = 429; Headers = @{ "Retry-After" = "300" } })
    throw $e
  }
  return [PSCustomObject]@{ five_hour = [PSCustomObject]@{ utilization = 61; resets_at = $apiFuture }; seven_day = [PSCustomObject]@{ utilization = 8; resets_at = $apiFuture } }
}

function Read-AccountCredential {
  param($Acc)
  return [PSCustomObject]@{ claudeAiOauth = [PSCustomObject]@{ accessToken = "faux"; expiresAt = 0; subscriptionType = "pro" } }
}

function Set-ApiCacheAge {
  param([int]$Age)
  $m = Read-UsageCache
  $m["appel"] = [PSCustomObject]@{ At = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $Age; Pct5 = 20; Reset5 = $apiFuture; Pct7 = 3; Reset7 = $apiFuture; Fails = 0; Until = 0 }
  Write-UsageCache $m
}

function Write-ApiDisplay {
  param([string]$Text)
  New-Item -ItemType Directory -Force -Path (Split-Path $apiDisplay) | Out-Null
  [IO.File]::WriteAllText($apiDisplay, $Text, (New-Object Text.UTF8Encoding($false)))
}

try {
  New-Item -ItemType Directory -Force -Path (Split-Path $script:UsageCachePath) | Out-Null
  Write-ApiDisplay '{ "usagePoll": 60 }'
  Set-ApiCacheAge 45
  $u = Get-AccountUsage $apiAcc
  Assert-Equal 0 $script:UsageApiCalls "donnees de 45 s, delai de 60 s : aucun appel"
  Assert-Equal 20 $u.Pct5 "donnees de 45 s, delai de 60 s : chiffres du cache"
  Assert-True ([math]::Abs([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - 45 - [long]$u.At) -le 2) "donnees du cache : heure de lecture rendue"

  Set-ApiCacheAge 70
  $u = Get-AccountUsage $apiAcc
  Assert-Equal 1 $script:UsageApiCalls "donnees de 70 s, delai de 60 s : un seul appel"
  Assert-Equal 61 $u.Pct5 "donnees de 70 s, delai de 60 s : chiffres de l'API"
  Assert-True ([math]::Abs([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - [long]$u.At) -le 2) "lecture de l'API : heure de lecture rendue"
  $u = Get-AccountUsage $apiAcc
  Assert-Equal 1 $script:UsageApiCalls "lecture de l'API gardee : pas de second appel"
  Assert-Equal 61 $u.Pct5 "lecture de l'API gardee : chiffres relus"

  Remove-Item -LiteralPath $apiDisplay -Force
  Set-ApiCacheAge 45
  $null = Get-AccountUsage $apiAcc
  Assert-Equal 2 $script:UsageApiCalls "sans reglage, delai de 30 s : donnees de 45 s relues"

  Write-ApiDisplay '{ "usagePoll": 60 }'
  Set-ApiCacheAge 500
  New-Item -ItemType Directory -Force -Path (Split-Path $apiState) | Out-Null
  $apiNow = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $lines = @(("q_at@claude-appel " + ($apiNow - 5)), ("q5_at@claude-appel " + ($apiNow + 3600)), "q5_pct@claude-appel 33", ("q7_at@claude-appel " + ($apiNow + 86400)), "q7_pct@claude-appel 4")
  [IO.File]::WriteAllText($apiState, (($lines -join "`n") + "`n"), (New-Object Text.UTF8Encoding($false)))
  $u = Get-AccountUsage $apiAcc
  Assert-Equal 2 $script:UsageApiCalls "barre plus recente que le cache : aucun appel"
  Assert-Equal 33 $u.Pct5 "barre plus recente que le cache : chiffres de la barre"
  Remove-Item -LiteralPath $apiState -Force

  Set-ApiCacheAge 500
  Save-UsageCooldown "appel" 120 1
  $u = Get-AccountUsage $apiAcc 0
  Assert-Equal 2 $script:UsageApiCalls "pause de l'API en cours : aucun appel"
  Assert-True ($u.LimitedUntil -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() + 100) "pause de l'API en cours : fin de pause rendue"

  Set-ApiCacheAge 500
  $script:UsageLockWaitMs = 300
  $apiLock = Open-MachineLock ("usage-" + (Get-StateTag (Get-AccountPath $apiAcc)))
  try {
    $u = Get-AccountUsage $apiAcc 0
    Assert-Equal 2 $script:UsageApiCalls "lecture tenue par un autre clm : aucun appel"
    Assert-Equal "20 " ("" + $u.Pct5 + " " + $u.Error) "lecture tenue par un autre clm : chiffres connus"
    $m = Read-UsageCache
    $m.Remove("appel")
    Write-UsageCache $m
    $u = Get-AccountUsage $apiAcc 0
    Assert-Equal 2 $script:UsageApiCalls "lecture tenue, rien de connu : aucun appel"
    Assert-Equal "API de suivi occupee" $u.Error "lecture tenue, rien de connu : API occupee"
  } finally { Close-MachineLock $apiLock }
  $script:UsageLockWaitMs = $apiLockWait

  Set-ApiCacheAge 500
  $script:UsageApiRefuse = $true
  $u = Get-AccountUsage $apiAcc 0
  $apiLeft = [long]$u.LimitedUntil - [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  Assert-Equal 3 $script:UsageApiCalls "refus 429 : un appel"
  Assert-True ($apiLeft -ge 295 -and $apiLeft -le 306) "refus 429 avec Retry-After 300 : pause de 300 s"
  Assert-True ((Get-CooldownLeft (Read-UsageCache)["appel"]) -ge 295) "refus 429 : pause gardee dans le cache"
  $u = Get-AccountUsage $apiAcc 0
  Assert-Equal 3 $script:UsageApiCalls "refus 429 : lecture suivante sans appel"
  Assert-Equal 20 $u.Pct5 "refus 429 : chiffres connus gardes"
} finally {
  $script:UsageLockWaitMs = $apiLockWait
  foreach ($n in @("Invoke-UsageApi", "Read-AccountCredential")) {
    if ($apiKept.ContainsKey($n)) { Set-Item ("function:" + $n) $apiKept[$n] } else { Remove-Item ("function:" + $n) -ErrorAction SilentlyContinue }
  }
  foreach ($p in @($script:UsageCachePath, $apiState, $apiDisplay)) {
    if ($apiFiles.ContainsKey($p)) { [IO.File]::WriteAllBytes($p, $apiFiles[$p]) } else { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue }
  }
}
