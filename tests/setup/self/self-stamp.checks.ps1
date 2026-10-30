$stampDir = Join-Path $script:Sandbox "stamp-bin"
$stampSha = "1234567abcdef1234567abcdef1234567abcdef1"
$null = New-Item -ItemType Directory -Path $stampDir -Force
Assert-Equal "" (Read-ClmStamp $stampDir) "marque : rien d'installe"
$null = New-SandboxFile "stamp-bin/clm.version" ($stampSha + " 1770000000 7`n")
Assert-Equal ($stampSha + " 1770000000 7") (Read-ClmStamp $stampDir) "marque : texte de la version"
$stampMarker = New-SandboxFile "stamp-bin/clm.installing" "1"
Assert-Equal "installing" (Read-ClmStamp $stampDir) "marque : installation en cours"
[IO.File]::SetLastWriteTimeUtc($stampMarker, [DateTime]::UtcNow.AddSeconds(-200))
Assert-Equal ($stampSha + " 1770000000 7") (Read-ClmStamp $stampDir) "marque : marqueur abandonne ignore"

$stampRead = (Get-Item "function:Read-ClmStamp").ScriptBlock
$stampShaFn = (Get-Item "function:Get-ClmSha").ScriptBlock
$stampLoaded = $script:ClmLoadedSha
$script:StampNow = ""
$script:StampDisk = ""
function Read-ClmStamp { param([string]$Dir = "") return $script:StampNow }
function Get-ClmSha { param([string]$Dir = "") return $script:StampDisk }
try {
  $script:ClmLoadedSha = "a" * 40
  $script:StampNow = ("b" * 40) + " 1770000000 7"
  $script:StampDisk = "b" * 40
  Assert-True (Test-ClmReplaced) "remplace : autre version posee"
  $script:StampNow = "installing"
  Assert-True (-not (Test-ClmReplaced)) "remplace : pas pendant une installation"
  $script:StampNow = ""
  $script:StampDisk = ""
  Assert-True (-not (Test-ClmReplaced)) "remplace : pas sans version sur le disque"
  $script:StampNow = ("a" * 40) + " 1770000000 7"
  $script:StampDisk = "a" * 40
  Assert-True (-not (Test-ClmReplaced)) "remplace : meme version"

  $script:StampNow = "v1"
  Assert-True (Test-ClmStampSteady "v1") "marque stable : rien n'a bouge"
  Assert-True (-not (Test-ClmStampSteady "v0")) "marque stable : version changee pendant le chargement"
  $script:StampNow = "installing"
  Assert-True (-not (Test-ClmStampSteady "v1")) "marque stable : installation commencee pendant le chargement"
  Assert-True (-not (Test-ClmStampSteady "installing")) "marque stable : charge pendant une installation"
} finally {
  Set-Item "function:Read-ClmStamp" $stampRead
  Set-Item "function:Get-ClmSha" $stampShaFn
  $script:ClmLoadedSha = $stampLoaded
}
