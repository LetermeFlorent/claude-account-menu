$ulAcc = [PSCustomObject]@{ Label = "ultra"; Dir = ".claude-ultra" }
$ulFuture = [DateTimeOffset]::UtcNow.AddHours(30).ToString("o")
$ulKept = @{}
foreach ($n in @("Invoke-UsageApi", "Invoke-ProfileApi", "Get-UsageToken")) { $ulKept[$n] = (Get-Item ("function:" + $n)).ScriptBlock }
$script:UlProfileCalls = 0
$script:UlFive = $null

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
  return [PSCustomObject]@{ organization = [PSCustomObject]@{ plan_display_name = "Ultra" } }
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

  $ulBar = [PSCustomObject]@{ At = [long]$ulCached.At + 10; Pct5 = $null; Reset5 = $null; Pct7 = 41; Reset7 = $ulFuture; No5 = $null; Plan = $null; Fails = 0; Until = 0 }
  $ulPick = Select-NewestUsage $ulCached $ulBar
  Assert-True ($ulPick.No5 -and $ulPick.Plan -eq "Ultra") "ultra : une lecture plus recente de la barre d'etat garde le forfait"

  $ulTag = "@" + (Get-StateTag (Get-AccountPath $ulAcc))
  $ulMap = @{ ("q_at" + $ulTag) = "1800000000"; ("q7_at" + $ulTag) = "1800003600"; ("q7_pct" + $ulTag) = "40"; ("q5_none" + $ulTag) = "1" }
  Assert-True (Read-StatusUsage $ulAcc $ulMap).No5 "ultra : la barre d'etat dit qu'il n'y a pas de 5h"
  Assert-True (@(Get-StatusEntries "t" $ulRow) -contains "q5_none@t 1") "ultra : clm ecrit l'absence de 5h pour la barre d'etat"

  Assert-True (-not ((Format-Row $ulRow) -match "\| 5h ")) "ultra : la ligne texte n'a pas de 5h"
  $ulSegs = Get-CompactUsageSegs @{ Usage = $ulRow; Cells = 8; Now = 0 }
  Assert-True (-not (@(foreach ($s in $ulSegs) { $s[0] }) -contains "5h ")) "ultra : la carte compacte n'a pas de 5h"

  $script:UlFive = [PSCustomObject]@{ utilization = 12; resets_at = $ulFuture }
  $ulMax = New-UsageRow $ulAcc "u@exemple.fr"
  Request-AccountUsage $ulMax $ulAcc $null $null
  Assert-True (-not $ulMax.No5) "ultra : avec une fenetre 5h envoyee, la ligne 5h reste"
  Assert-True ((Format-Row $ulMax) -match "\| 5h ") "ultra : la ligne texte garde le 5h quand il existe"
} finally {
  foreach ($n in $ulKept.Keys) { Set-Item ("function:" + $n) $ulKept[$n] }
  $null = Update-UsageCache { param($map) $map.Remove("ultra") }
}
