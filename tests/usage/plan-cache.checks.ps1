$planAcc = [PSCustomObject]@{ Label = "forfait"; Dir = ".claude-forfait" }
$planFile = Join-Path (Get-AccountPath $planAcc) ".credentials.json"
$planOs = $script:OsName
$planKept = (Get-Item "function:Read-AccountCredential").ScriptBlock
$planReal = $planKept
$script:PlanReads = 0

function Read-AccountCredential {
  param($Acc)
  $script:PlanReads++
  return & $planReal $Acc
}

function Write-PlanCredential {
  param([string]$Type, [int]$Skew = 0)
  $cred = [PSCustomObject]@{ claudeAiOauth = [PSCustomObject]@{ accessToken = "t"; expiresAt = 0; subscriptionType = $Type } }
  New-Item -ItemType Directory -Force -Path (Split-Path $planFile) | Out-Null
  Write-CredentialFile $planFile $cred
  if ($Skew -ne 0) { [IO.File]::SetLastWriteTimeUtc($planFile, [DateTime]::UtcNow.AddSeconds($Skew)) }
}

function Set-PlanCache {
  $m = Read-UsageCache
  $at = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - 5
  $m["forfait"] = [PSCustomObject]@{ At = $at; Pct5 = 20; Reset5 = [DateTimeOffset]::UtcNow.AddHours(3).ToString("o"); Pct7 = 3; Reset7 = [DateTimeOffset]::UtcNow.AddHours(30).ToString("o"); Fails = 0; Until = 0 }
  New-Item -ItemType Directory -Force -Path (Split-Path $script:UsageCachePath) | Out-Null
  Write-UsageCache $m
}

function Read-PlanThrice {
  $plans = @()
  foreach ($i in 1..3) { Set-PlanCache; $plans += (Get-AccountUsage $planAcc).Plan }
  return $plans -join "|"
}

try {
  Write-PlanCredential "pro"
  $script:PlanReads = 0
  Assert-Equal "Pro|Pro|Pro" (Read-PlanThrice) "forfait : nom lu sur trois lectures"
  Assert-Equal 1 $script:PlanReads "forfait : fichier de jetons lu une seule fois sur trois lectures"

  Write-PlanCredential "max" 30
  Assert-Equal "Max|Max|Max" (Read-PlanThrice) "forfait : fichier change, nom relu"
  Assert-Equal 2 $script:PlanReads "forfait : fichier change, une seule relecture"

  Write-PlanCredential "team" 60
  Assert-Equal "Team|Team|Team" (Read-PlanThrice) "forfait : taille changee, nom relu"
  Assert-Equal 3 $script:PlanReads "forfait : taille changee, une seule relecture"

  Remove-Item -LiteralPath $planFile -Force
  Assert-Equal "||" (Read-PlanThrice) "forfait : fichier disparu, nom vide"
  Assert-Equal 4 $script:PlanReads "forfait : fichier disparu, une seule relecture"

  $script:OsName = "MacOS"
  $script:PlanCache = @{}
  $planReal = { param($Acc) [PSCustomObject]@{ claudeAiOauth = [PSCustomObject]@{ accessToken = "t"; expiresAt = 0; subscriptionType = "pro" } } }
  $script:PlanReads = 0
  $null = Read-PlanThrice
  $planReal = { param($Acc) [PSCustomObject]@{ claudeAiOauth = [PSCustomObject]@{ accessToken = "t"; expiresAt = 0; subscriptionType = "max" } } }
  Assert-Equal "Pro|Pro|Pro" (Read-PlanThrice) "forfait macOS : nom garde tant que clm tourne"
  Assert-Equal 1 $script:PlanReads "forfait macOS : une seule lecture du trousseau"
} finally {
  $script:OsName = $planOs
  $script:PlanCache = @{}
  Set-Item "function:Read-AccountCredential" $planKept
  Remove-Item -LiteralPath (Get-AccountPath $planAcc) -Recurse -Force -ErrorAction SilentlyContinue
  $planMap = Read-UsageCache
  $planMap.Remove("forfait")
  Write-UsageCache $planMap
}
