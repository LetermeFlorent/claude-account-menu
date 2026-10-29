$raceLab = Split-Path -Parent $PSScriptRoot
. (Join-Path $raceLab "race-helpers.ps1")
. (Join-Path $PSScriptRoot "race-install.ps1")

$upHome = New-RaceHome "update-race"
New-RaceRelease $upHome.Root
$upChild = Join-Path $PSScriptRoot "update-child.ps1"
$upParams = @(foreach ($n in 1..3) { @{ Bin = $upHome.Bin; Lab = $raceLab; Dir = $upHome.Root; Id = ("u" + $n) } })
$upRuns = Invoke-Race $upChild $upParams $upHome.Root $upHome.Env
$newSha = $script:RaceNewVersion.Split(" ")[0]
Assert-Equal "" (Format-RaceFailures $upRuns) "trois clm se mettent a jour en meme temps : aucune erreur"
Assert-Equal 1 @(Get-ChildItem -LiteralPath $upHome.Root -Filter "install-*").Count "trois clm se mettent a jour en meme temps : un seul installe"
Assert-Equal ("result u1 True " + $newSha + "|result u2 True " + $newSha + "|result u3 True " + $newSha) (Get-RaceResults $upRuns) "trois clm se mettent a jour en meme temps : tous repartent sur la nouvelle version"
Assert-True (-not ((@($upRuns | ForEach-Object { $_.Out }) -join " ") -match "impossible")) "trois clm se mettent a jour en meme temps : aucun message d'echec"
