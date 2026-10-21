. (Join-Path $PSScriptRoot "claude-drive-api.ps1")
. (Join-Path $PSScriptRoot "claude-drive-state.ps1")
$script:RemoteCachePath = Join-Path (Get-HomeDir) ".clm-drive-remote.json"
$script:RemoteFullSeconds = 24 * 3600
$script:RemoteCacheMemo = $null

function New-RemoteCache {
  param([string]$Folder, [string]$Token, [long]$Full, $Files)
  $ids = New-PathMap
  foreach ($k in $Files.Keys) { $ids[[string]$Files[$k].Id] = $k }
  return @{ Folder = $Folder; Token = $Token; Full = $Full; Files = $Files; Ids = $ids }
}

function ConvertTo-RemoteCacheText {
  param($Cache)
  $rows = New-Object 'System.Collections.Generic.List[string]'
  foreach ($k in $Cache.Files.Keys) {
    $e = $Cache.Files[$k]
    $n = '"' + $k + '"'; $i = '"' + $e.Id + '"'; $d = '"' + $e.Md5 + '"'; $p = '"' + $e.Pc + '"'
    if (-not $script:PlainJsonText.IsMatch($k + $e.Id + $e.Md5 + $e.Pc)) { $n = ConvertTo-JsonString $k; $i = ConvertTo-JsonString $e.Id; $d = ConvertTo-JsonString $e.Md5; $p = ConvertTo-JsonString $e.Pc }
    $rows.Add('    {"id": ' + $i + ', "name": ' + $n + ', "md5": ' + $d + ', "m": ' + [long]$e.M + ', "pc": ' + $p + ', "exp": ' + [long]$e.Exp + '}')
  }
  $head = "{`n  ""folder"": " + (ConvertTo-JsonString $Cache.Folder) + ",`n  ""token"": " + (ConvertTo-JsonString $Cache.Token) + ",`n  ""full"": " + [long]$Cache.Full
  return $head + ",`n  ""files"": [`n" + [string]::Join(",`n", $rows) + "`n  ]`n}`n"
}

function Get-RemoteCacheStamp {
  $info = New-Object IO.FileInfo $script:RemoteCachePath
  if (-not $info.Exists) { return "" }
  return "" + $info.LastWriteTimeUtc.Ticks + "|" + $info.Length
}

function Save-RemoteCache {
  param($Cache)
  Write-TextFileAtomic $script:RemoteCachePath (ConvertTo-RemoteCacheText $Cache)
  $script:RemoteCacheMemo = @{ Stamp = (Get-RemoteCacheStamp); Cache = $Cache }
}

function ConvertFrom-RemoteCacheData {
  param($Data)
  $files = New-PathMap
  foreach ($v in @($Data["files"])) {
    if ($null -eq $v) { continue }
    $props = @{ m = [string]$v["m"]; pc = [string]$v["pc"]; exp = [string]$v["exp"] }
    $files[[string]$v["name"]] = New-RemoteEntry ([string]$v["id"]) ([string]$v["name"]) ([string]$v["md5"]) $props
  }
  return New-RemoteCache ([string]$Data["folder"]) ([string]$Data["token"]) ([long]$Data["full"]) $files
}

function Read-RemoteCache {
  try {
    $stamp = Get-RemoteCacheStamp
    if (-not $stamp) { return $null }
    if ($null -ne $script:RemoteCacheMemo -and $script:RemoteCacheMemo.Stamp -eq $stamp) { return $script:RemoteCacheMemo.Cache }
    $data = Read-JsonFile $script:RemoteCachePath
    if ($null -eq $data) { return $null }
    $cache = ConvertFrom-RemoteCacheData $data
    $script:RemoteCacheMemo = @{ Stamp = $stamp; Cache = $cache }
    return $cache
  } catch { return $null }
}

function Test-RemoteCacheUsable {
  param($Cache, [string]$FolderId)
  if ($null -eq $Cache -or $Cache.Folder -cne $FolderId -or -not $Cache.Token) { return $false }
  $age = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $Cache.Full
  return $age -ge 0 -and $age -lt $script:RemoteFullSeconds
}
