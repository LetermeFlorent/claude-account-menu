$ulAcc = [PSCustomObject]@{ Label = "ultra"; Dir = ".claude-ultra" }
$ulFuture = [DateTimeOffset]::UtcNow.AddHours(30).ToString("o")
$ulKept = @{}
foreach ($n in @("Invoke-UsageApi", "Invoke-ProfileApi", "Get-UsageToken")) { $ulKept[$n] = (Get-Item ("function:" + $n)).ScriptBlock }
$script:UlProfileCalls = 0
$script:UlFive = $null
$script:UlPlan = "Ultra"

function Get-UsageToken {
  param($Acc, $Cred, [switch]$NoRefresh)
  return @{ Token = "faux" }
}

function Invoke-UsageApi {
  param([string]$Token)
  return [PSCustomObject]@{ five_hour = $script:UlFive; seven_day = [PSCustomObject]@{ utilization = 40; resets_at = $ulFuture } }
}

function Invoke-ProfileApi {
  param([string]$Token)
  $script:UlProfileCalls++
  return [PSCustomObject]@{ organization = [PSCustomObject]@{ plan_display_name = $script:UlPlan } }
}

try {
  $ulRow = New-UsageRow $ulAcc "u@exemple.fr"
  Request-AccountUsage $ulRow $ulAcc $null $null
  Assert-True $ulRow.No5 "ultra : sans fenetre 5h envoyee, la ligne 5h disparait"
  Assert-Equal "Ultra" $ulRow.Plan "ultra : le nom du forfait vient de Claude"
  Request-AccountUsage (New-UsageRow $ulAcc "u@exemple.fr") $ulAcc $null $null
  Assert-Equal 1 $script:UlProfileCalls "ultra : le nom du forfait est lu une seule fois par connexion"

  $ulCached = (Read-UsageCache)["ultra"]
  $ulCopy = New-UsageRow $ulAcc "u@exemple.fr"
  Copy-CacheEntry $ulCached $ulCopy
  Assert-True ($ulCopy.No5 -and $ulCopy.Plan -eq "Ultra") "ultra : le cache garde le forfait et l'absence de 5h"

  Assert-True (@(Get-StatusEntries "t" $ulRow) -contains "q5_none@t 1") "ultra : clm ecrit l'absence de 5h pour la barre d'etat"

  Assert-True (-not ((Format-Row $ulRow) -match "\| 5h ")) "ultra : la ligne texte n'a pas de 5h"
  $ulSegs = Get-CompactUsageSegs @{ Usage = $ulRow; Cells = 8; Now = 0 }
  Assert-True (-not (@(foreach ($s in $ulSegs) { $s[0] }) -contains "5h ")) "ultra : la carte compacte n'a pas de 5h"

  $script:UlPlan = "Max"
  $script:ApiPlanCache = @{}
  $ulIdle = New-UsageRow $ulAcc "u@exemple.fr"
  Request-AccountUsage $ulIdle $ulAcc $null $null
  Assert-True (-not $ulIdle.No5) "max : sans fenetre 5h envoyee, la ligne 5h reste pour un compte non Ultra"
  $ulMaxCached = (Read-UsageCache)["ultra"]
  $ulMaxCopy = New-UsageRow $ulAcc "u@exemple.fr"
  Copy-CacheEntry ([PSCustomObject]@{ At = $ulMaxCached.At; Pct7 = 40; Reset7 = $ulFuture; No5 = $true; Plan = "Max" }) $ulMaxCopy
  Assert-True (-not $ulMaxCopy.No5) "max : un ancien cache sans 5h ne cache plus le 5h d'un compte non Ultra"
  $script:UlPlan = "Ultra"
  $script:UlFive = [PSCustomObject]@{ utilization = 12; resets_at = $ulFuture }
  $ulMax = New-UsageRow $ulAcc "u@exemple.fr"
  Request-AccountUsage $ulMax $ulAcc $null $null
  Assert-True (-not $ulMax.No5) "ultra : avec une fenetre 5h envoyee, la ligne 5h reste"
  Assert-True ((Format-Row $ulMax) -match "\| 5h ") "ultra : la ligne texte garde le 5h quand il existe"
} finally {
  foreach ($n in $ulKept.Keys) { Set-Item ("function:" + $n) $ulKept[$n] }
  $null = Update-UsageCache { param($map) $map.Remove("ultra") }
}
$ulNames = @(
  @{ subscriptionType = "max"; rateLimitTier = "default_claude_max_20x" },
  @{ subscriptionType = "max"; rateLimitTier = "default_claude_max_5x" },
  @{ subscriptionType = "pro"; rateLimitTier = "default_claude_pro" },
  @{ subscriptionType = "free" }
) | ForEach-Object { Get-PlanName ([PSCustomObject]$_) }
Assert-Equal "Ultra Max Pro Free" ($ulNames -join " ") "offre sans nom de Claude : Ultra, Max, Pro et Free, sans 20x ni 5x"
Assert-True ((Get-PlanColor "Ultra") -ne (Get-PlanColor "Max") -and (Get-PlanColor "Max") -ne (Get-PlanColor "Pro")) "Ultra, Max et Pro gardent chacun leur couleur"
$ulOut = [PSCustomObject]@{ Label = "c2"; Email = "c2@b.c"; Plan = "Ultra"; Error = (Get-ClmText "ui.usage.signedOut"); No5 = $true }
Assert-Equal ("c2 c2@b.c | " + (Get-ClmText "ui.usage.signedOut")) (Format-Row $ulOut) "compte non connecte : seulement le message, sans offre ni quotas"
