$staleAcc = [PSCustomObject]@{ Label = "perime"; Dir = ".claude-perime" }
$stalePast = [DateTimeOffset]::UtcNow.AddMinutes(-10).ToString("o")
$staleFuture = [DateTimeOffset]::UtcNow.AddHours(3).ToString("o")
$staleKept = @{}
foreach ($n in @("Invoke-UsageApi", "Read-AccountCredential")) {
  $f = Get-Item ("function:" + $n) -ErrorAction SilentlyContinue
  if ($null -ne $f) { $staleKept[$n] = $f.ScriptBlock }
}
$script:StaleApiAnswer = "refus"

function Invoke-UsageApi {
  param([string]$Token)
  if ($script:StaleApiAnswer -eq "zero") { return [PSCustomObject]@{ five_hour = [PSCustomObject]@{ utilization = 0; resets_at = $null }; seven_day = [PSCustomObject]@{ utilization = 4; resets_at = $staleFuture } } }
  $e = New-Object Exception "trop de requetes"
  Add-Member -InputObject $e -NotePropertyName Response -NotePropertyValue ([PSCustomObject]@{ StatusCode = 429; Headers = @{ "Retry-After" = "60" } })
  throw $e
}

function Read-AccountCredential {
  param($Acc)
  return [PSCustomObject]@{ claudeAiOauth = [PSCustomObject]@{ accessToken = "faux"; expiresAt = 0; subscriptionType = "pro" } }
}

function Set-StaleCache {
  param($Pct5, $Reset5, [bool]$No5 = $false, [int]$Age = 500)
  $m = Read-UsageCache
  $m["perime"] = [PSCustomObject]@{ At = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $Age; Pct5 = $Pct5; Reset5 = $Reset5; Pct7 = 30; Reset7 = $staleFuture; No5 = $No5; Plan = ""; Fails = 0; Until = 0 }
  Write-UsageCache $m
}

try {
  New-Item -ItemType Directory -Force -Path (Split-Path $script:UsageCachePath) | Out-Null
  Set-StaleCache 80 $stalePast
  $u = Get-AccountUsage $staleAcc 0
  Assert-Equal "0 30" ("" + $u.Pct5 + " " + $u.Pct7) "cache a 80 %, reset 5h passe, API refusee : 5h remis a 0, 7d garde"
  Assert-True $u.Expired "cache a 80 %, reset 5h passe, API refusee : fenetre marquee passee"

  Set-StaleCache 80 $stalePast
  $script:StaleApiAnswer = "zero"
  $u = Get-AccountUsage $staleAcc 0
  Assert-Equal 0 $u.Pct5 "API a 0 % : remplace les 80 % du cache"
  Assert-Equal 0 (Read-UsageCache)["perime"].Pct5 "API a 0 % : cache a 0"
  $script:StaleApiAnswer = "refus"

  Set-StaleCache $null $null $true
  $u = Get-AccountUsage $staleAcc 0
  Assert-Null $u.Pct5 "compte sans fenetre 5h : rien d'invente apres un refus"

  Set-StaleCache 80 $staleFuture $false 10
  $st = New-MenuState @($staleAcc) 0 $false
  $se = $st.Entries[0]
  $se.Pending = $false
  $se.NextAt = 9000000
  Assert-Equal 80 $se.U.Pct5 "menu ouvert : 80 % du cache"
  $se.U.Reset5 = $stalePast
  $staleRow = New-UsageRow $staleAcc "perime@x.fr"
  $staleRow.Error = Get-ClmText "ui.usage.unreachable"
  $se.Pending = $true
  Set-UsageResult $st @(0, $staleRow, $null) 1000
  $se.NextAt = 9000000
  $null = Step-MenuLoader $st 4000
  Assert-Equal 0 $se.U.Pct5 "reset 5h passe menu ouvert, lecture en echec : plus 80 %"
  Assert-Equal 0 $se.T5.To "reset 5h passe menu ouvert : barre vers 0"
  Assert-True $se.U.Expired "reset 5h passe menu ouvert : fenetre marquee passee"

  Set-StaleCache 80 $staleFuture $false 10
  $st = New-MenuState @($staleAcc) 0 $false
  $se = $st.Entries[0]
  $se.Pending = $false
  $se.NextAt = 9000000
  $se.U.Reset5 = $stalePast
  Save-UsageCooldown "perime" 120 1
  $null = Step-MenuLoader $st 4000
  Assert-Equal 0 $se.U.Pct5 "reset 5h passe, cache relu d'un autre clm en pause : plus 80 %"
} finally {
  foreach ($n in @("Invoke-UsageApi", "Read-AccountCredential")) {
    if ($staleKept.ContainsKey($n)) { Set-Item ("function:" + $n) $staleKept[$n] } else { Remove-Item ("function:" + $n) -ErrorAction SilentlyContinue }
  }
  $m = Read-UsageCache
  $m.Remove("perime")
  Write-UsageCache $m
}
