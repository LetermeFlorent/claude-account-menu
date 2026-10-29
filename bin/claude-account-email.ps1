$script:AccountEmailCache = @{}
$script:AccountEmailReads = 0
$script:AccountEmailSettleSeconds = 3

function Get-FileStamp {
  param([string]$Path)
  $info = New-Object IO.FileInfo $Path
  $info.Refresh()
  if (-not $info.Exists) { return $null }
  return [PSCustomObject]@{ Ticks = $info.LastWriteTimeUtc.Ticks; Length = $info.Length }
}

function Read-AccountEmail {
  param([string]$Path)
  $stamp = Get-FileStamp $Path
  if ($null -eq $stamp) { $script:AccountEmailCache.Remove($Path); return "" }
  $hit = $script:AccountEmailCache[$Path]
  if ($null -ne $hit -and $hit.Ticks -eq $stamp.Ticks -and $hit.Length -eq $stamp.Length) { return $hit.Email }
  $script:AccountEmailReads++
  try { $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop } catch { return "" }
  $email = ""
  if ($raw -match '"oauthAccount"\s*:\s*\{[^}]*?"emailAddress"\s*:\s*"([^"]+)"') { $email = $Matches[1] }
  $settled = [DateTime]::UtcNow.Subtract([TimeSpan]::FromSeconds($script:AccountEmailSettleSeconds)).Ticks
  if ($stamp.Ticks -lt $settled) { $script:AccountEmailCache[$Path] = @{ Ticks = $stamp.Ticks; Length = $stamp.Length; Email = $email } }
  else { $script:AccountEmailCache.Remove($Path) }
  return $email
}
