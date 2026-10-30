function Test-ConsoleUtf8Needed {
  return $PSVersionTable.PSEdition -eq "Desktop" -and $env:OS -eq "Windows_NT"
}

function Use-ConsoleUtf8 {
  if (-not (Test-ConsoleUtf8Needed)) { return $null }
  try {
    $before = [Console]::OutputEncoding
    [Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
    return $before
  } catch { return $null }
}

function Restore-ConsoleEncoding {
  param($Before)
  if ($null -eq $Before) { return }
  try { [Console]::OutputEncoding = $Before } catch { Write-Verbose $_.Exception.Message }
}
