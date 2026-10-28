$script:DriveDeleteLimit = 20
$script:DeleteKinds = @("delete-local", "delete-remote")

function Select-RemoteFiles {
  param($Listing, $Patterns, $Roots)
  $out = New-PathMap
  $rx = Get-ExcludeRegex $Patterns
  $inRoots = Get-RootsRegex $Roots
  foreach ($k in $Listing.Keys) {
    if ($inRoots.IsMatch($k) -and -not $rx.IsMatch($k) -and (Test-SafeSyncPath $k)) { $out[$k] = $Listing[$k] }
  }
  return $out
}

function Read-SyncBase {
  param([string]$Root, $Roots)
  $state = Read-DriveState
  if ($state.Root -ne $Root) { $state = @{ At = [long]0; Root = $Root; Files = (New-PathMap) } }
  $inRoots = Get-RootsRegex $Roots
  foreach ($k in @($state.Files.Keys)) { if (-not $inRoots.IsMatch($k)) { $state.Files.Remove($k) } }
  return $state
}

function Get-RegistryMd5 {
  param($Files)
  $e = $Files[$script:RegistryName]
  if ($null -eq $e) { return "" }
  return [string]$e.Md5
}

function Get-CountedDeletes {
  param($Plan, $Exempt)
  $n = 0
  foreach ($a in @($Plan)) {
    if ($script:DeleteKinds -notcontains $a.Kind) { continue }
    $skill = Get-SkillOfPath $a.Path
    if (-not ($skill -and $null -ne $Exempt -and $Exempt.ContainsKey($skill))) { $n++ }
  }
  return $n
}

function Assert-DeleteLimit {
  param($Plan, [int]$BaseCount, [bool]$Force, $Exempt = $null)
  $n = Get-CountedDeletes $Plan $Exempt
  $limit = [math]::Max($script:DriveDeleteLimit, [int][math]::Floor($BaseCount / 10))
  if ($n -gt $limit -and -not $Force) { throw ("synchro bloquee : " + $n + " suppressions prevues, verifier puis lancer clm --sync --force") }
}
