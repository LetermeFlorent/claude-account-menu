$script:RestoreWatchedKeys = @("apiKeyHelper", "awsAuthRefresh", "awsCredentialExport", "env", "hooks", "mcpServers", "otelHeadersHelper", "permissions")
$script:RestoreWatchedFiles = @("settings.json", "settings.local.json", ".claude.json")
$script:RestoreProjectsKey = "projects.mcpServers"

function Read-JsonObject {
  param([string]$Path)
  if (-not [IO.File]::Exists($Path)) { return $null }
  try { return [IO.File]::ReadAllText($Path) | ConvertFrom-Json } catch { Write-Verbose ("reglages illisibles : " + $Path); return $null }
}

function Get-WatchedValues {
  param($Json)
  $out = @{}
  if ($null -eq $Json -or $Json -isnot [PSCustomObject]) { return $out }
  foreach ($k in $script:RestoreWatchedKeys) {
    if ($Json.PSObject.Properties[$k]) { $out[$k] = ConvertTo-Json -InputObject $Json.$k -Depth 40 -Compress }
  }
  $projects = $Json.PSObject.Properties["projects"]
  if ($null -eq $projects -or $projects.Value -isnot [PSCustomObject]) { return $out }
  $mcp = [ordered]@{}
  foreach ($p in $projects.Value.PSObject.Properties) {
    if ($p.Value -is [PSCustomObject] -and $p.Value.PSObject.Properties["mcpServers"]) { $mcp[$p.Name] = $p.Value.mcpServers }
  }
  if ($mcp.Count -gt 0) { $out[$script:RestoreProjectsKey] = ConvertTo-Json -InputObject $mcp -Depth 40 -Compress }
  return $out
}

function Get-ChangedKeys {
  param($Before, $After)
  $names = @(@($Before.Keys) + @($After.Keys) | Sort-Object -Unique)
  return @($names | Where-Object { [string]$Before[$_] -cne [string]$After[$_] })
}

function Get-RestoreCandidates {
  param($Accs, $Listing)
  foreach ($i in @(Get-AccountItems $Accs)) {
    foreach ($c in @($i) + @($script:RestoreWatchedFiles | ForEach-Object { $i + "/" + $_ })) {
      if ($c -match '\.json\z' -and $Listing -ccontains $c) { $c }
    }
  }
}

function Get-RestoreChanges {
  param([string]$Zip, $Accs)
  $want = @(Get-RestoreCandidates $Accs @(& $script:Tar -tf $Zip))
  if ($want.Count -eq 0) { return @() }
  $tmp = Join-Path ([IO.Path]::GetTempPath()) ("claude-check-" + [guid]::NewGuid().ToString("N"))
  $null = [IO.Directory]::CreateDirectory($tmp)
  try {
    $null = & $script:Tar -x -f $Zip -C $tmp @want 2>&1
    return @(foreach ($w in $want) {
      $keys = Get-ChangedKeys (Get-WatchedValues (Read-JsonObject (Join-Path $script:HomeDir $w))) (Get-WatchedValues (Read-JsonObject (Join-Path $tmp $w)))
      if ($keys.Count -gt 0) { $w + " : " + ($keys -join ", ") }
    })
  } finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}
