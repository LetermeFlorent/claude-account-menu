. (Join-Path $PSScriptRoot "claude-drive-files.ps1")

function Get-OwnLeftovers {
  param($Listing, [string]$Pc)
  $ids = New-Object 'System.Collections.Generic.List[string]'
  foreach ($k in $Listing.Keys) {
    $e = $Listing[$k]
    if ($e.Pc -eq $Pc -and (Test-SyncExcluded $k $script:SyncLocalOnly)) { $ids.Add($e.Id) }
  }
  return ,$ids.ToArray()
}

function Remove-OwnLeftovers {
  param($Listing, [string]$Pc, $Ctl, [long]$DeadlineMs)
  $n = 0
  foreach ($id in (Get-OwnLeftovers $Listing $Pc)) {
    if (Test-SyncStop $Ctl $DeadlineMs) { break }
    Remove-DriveFile $id
    $n++
  }
  return $n
}
