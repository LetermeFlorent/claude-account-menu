. (Join-Path $bin "web/server/claude-web-state.ps1")
$decAcc = [PSCustomObject]@{ Label = "decimale"; Dir = ".claude-decimale" }
$decFuture = [DateTimeOffset]::UtcNow.AddHours(30).ToString("o")
$decKept = @{}
foreach ($n in @("Invoke-UsageApi", "Invoke-ProfileApi", "Get-UsageToken")) { $decKept[$n] = (Get-Item ("function:" + $n)).ScriptBlock }
$decLang = $env:CLM_LANG

function Get-UsageToken {
  param($Acc, $Cred, [switch]$NoRefresh)
  return @{ Token = "faux" }
}

function Invoke-UsageApi {
  param([string]$Token)
  return [PSCustomObject]@{ five_hour = [PSCustomObject]@{ utilization = 25.3; resets_at = $decFuture }; seven_day = [PSCustomObject]@{ utilization = 25.0; resets_at = $decFuture } }
}

function Invoke-ProfileApi {
  param([string]$Token)
  return [PSCustomObject]@{ organization = [PSCustomObject]@{ plan_display_name = "Max" } }
}

function Get-DecimalLine {
  param($U)
  $esc = [string][char]27
  return (ConvertTo-LineText (Get-CompactUsageSegs @{ Usage = $U; Cells = 8; Now = 0 }) 999) -replace ($esc + "\[[0-9;]*m"), ""
}

try {
  $env:CLM_LANG = "en"
  $decWant = @{ "25" = "25"; "25.3" = "25.3"; "99.96" = "100"; "0" = "0"; "100" = "100"; "99.94" = "99.9"; "25.04" = "25" }
  foreach ($k in $decWant.Keys) { Assert-Equal $decWant[$k] (Format-UsagePct ([double]::Parse($k, $script:Invariant))) ("decimale en : " + $k) }
  $env:CLM_LANG = "fr"
  Assert-Equal "25,3" (Format-UsagePct 25.3) "decimale fr : virgule"
  Assert-Equal "25" (Format-UsagePct 25.0) "decimale fr : pas de ,0"

  $decRow = New-UsageRow $decAcc "d@exemple.fr"
  Request-AccountUsage $decRow $decAcc $null $null
  Assert-Equal "25.3" $decRow.Pct5.ToString($script:Invariant) "decimale : la valeur de l'API n'est plus arrondie"
  Assert-True ((Format-Row $decRow) -match "5h 25,3% .*7d 25% ") "decimale : clm --usage en fr"
  $env:CLM_LANG = "en"
  Assert-True ((Format-Row $decRow) -match "5h 25\.3% .*7d 25% ") "decimale : clm --usage en en"
  $decText = Get-DecimalLine $decRow
  Assert-True ($decText -match " 25\.3% .*   25% ") ("decimale : ligne du menu [" + $decText + "]")
  Assert-Equal 25.3 (Get-WebQuota 25.3 $null "").pct "decimale : page web garde la decimale"
  Assert-Equal 100 (Get-WebQuota 99.96 $null "").pct "decimale : page web arrondie comme l'affichage"
  $decLines = @(Get-StatusEntries "t" $decRow)
  Assert-True ($decLines -contains "q5_pct@t 25.3" -and $decLines -contains "q7_pct@t 25") "decimale : barre d'etat sans ,0 ni arrondi"
  Assert-Equal ((Get-BarHue "7d" 30) -join ",") ((Get-BarHue "7d" 29.96) -join ",") "decimale : couleur selon la valeur affichee"
  $decFull = [PSCustomObject]@{ Pct5 = 10; Pct7 = 99.96; Error = $null; No5 = $false }
  Assert-True ((Get-UsageView $decFull).Badge -ne "") "decimale : 99.96 affiche 100 donc quota atteint"
  Assert-Equal 1 (Get-ReadyDefault @([PSCustomObject]@{ U = $decFull; Pending = $false }, [PSCustomObject]@{ U = [PSCustomObject]@{ Pct5 = 1; Pct7 = 1; Error = $null }; Pending = $false })) "decimale : compte a 100 affiche saute"
} finally {
  foreach ($n in $decKept.Keys) { Set-Item ("function:" + $n) $decKept[$n] }
  if ($null -eq $decLang) { Remove-Item Env:CLM_LANG -ErrorAction SilentlyContinue } else { $env:CLM_LANG = $decLang }
}
