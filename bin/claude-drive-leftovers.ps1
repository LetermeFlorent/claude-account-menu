. (Join-Path $PSScriptRoot "claude-drive-files.ps1")
$script:DriveBatchUri = "https://www.googleapis.com/batch/drive/v3"
$script:DriveBatchMax = 100
$script:DriveIdPattern = '^[A-Za-z0-9_-]+$'

function Get-OwnLeftovers {
  param($Listing, [string]$Pc, $Patterns)
  $ids = New-Object 'System.Collections.Generic.List[string]'
  $dropped = Get-ExcludeRegex $Patterns
  foreach ($k in $Listing.Keys) {
    $e = $Listing[$k]
    if (($e.Pc -eq $Pc -or -not $e.Pc) -and $e.Id -match $script:DriveIdPattern -and $dropped.IsMatch($k)) { $ids.Add($e.Id) }
  }
  return ,$ids.ToArray()
}

function New-TrashBatchBody {
  param([string[]]$Ids, [string]$Boundary)
  $sb = New-Object Text.StringBuilder
  foreach ($id in $Ids) {
    [void]$sb.Append("--" + $Boundary + "`r`nContent-Type: application/http`r`n`r`nPATCH /drive/v3/files/" + $id + "?fields=id`r`nContent-Type: " + $script:DriveJsonType + "`r`n`r`n{""trashed"":true}`r`n")
  }
  [void]$sb.Append("--" + $Boundary + "--`r`n")
  return $sb.ToString()
}

function Invoke-TrashBatch {
  param([string[]]$Ids)
  $boundary = "clm" + [guid]::NewGuid().ToString("N")
  $body = [Text.Encoding]::UTF8.GetBytes((New-TrashBatchBody $Ids $boundary))
  $r = Invoke-DriveRequest "POST" $script:DriveBatchUri $body ("multipart/mixed; boundary=" + $boundary) $script:DriveDataTimeout
  return ([regex]::Matches((Get-ResponseText $r), "HTTP/1\.1 2\d\d")).Count
}

function Remove-DriveFiles {
  param([string[]]$Ids, $Ctl, [long]$DeadlineMs)
  $n = 0
  for ($i = 0; $i -lt $Ids.Count; $i += $script:DriveBatchMax) {
    if (Test-SyncStop $Ctl $DeadlineMs) { break }
    $last = [math]::Min($i + $script:DriveBatchMax, $Ids.Count) - 1
    $n += Invoke-TrashBatch $Ids[$i..$last]
  }
  return $n
}

function Remove-OwnLeftovers {
  param($Listing, [string]$Pc, $Patterns, $Ctl, [long]$DeadlineMs)
  $ids = Get-OwnLeftovers $Listing $Pc $Patterns
  if ($ids.Count -eq 0) { return 0 }
  return Remove-DriveFiles $ids $Ctl $DeadlineMs
}
