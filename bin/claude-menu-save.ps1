. (Join-Path $PSScriptRoot "claude-menu-progress.ps1")
$script:SaveExcludes = @("cache", "paste-cache", "session-env", "shell-snapshots", "ide", "*.lock", ".local/bin/*.exe")
$script:Tar = Join-Path $env:SystemRoot "System32\tar.exe"

function Get-DownloadsDir {
  $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
  try {
    $raw = (Get-Item -LiteralPath $key).GetValue("{374DE290-123F-4565-9164-39C4925E467B}", $null, "DoNotExpandEnvironmentNames")
    if ($raw) {
      $p = [Environment]::ExpandEnvironmentVariables($raw)
      if (Test-Path -LiteralPath $p) { return $p }
    }
  } catch {}
  $p = Join-Path $env:USERPROFILE "Downloads"
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Path $p | Out-Null }
  return $p
}

function Get-AccountItems {
  param($Accs)
  $names = @()
  foreach ($a in $Accs) {
    $names += $a.Dir
    if ($a.Dir -eq ".claude") { $names += @(".claude.json", ".mcp.json") }
  }
  return $names
}

function Get-SaveItems {
  param($Accs)
  $h = $env:USERPROFILE
  $names = @(Get-AccountItems $Accs) + @(".claude-accounts.json")
  $items = $names | Where-Object { Test-Path -LiteralPath (Join-Path $h $_) }
  $bin = Get-ChildItem -LiteralPath $PSScriptRoot -File | Where-Object { $_.Name -match "^(clm|claude-.*)\.(cmd|ps1)$" } | ForEach-Object { ".local/bin/" + $_.Name }
  return @($items) + @($bin)
}

function Get-SaveExcludes {
  param($Accs)
  $ex = @($script:SaveExcludes)
  foreach ($acc in $Accs) {
    if ($acc.Dir -eq ".claude") { continue }
    foreach ($s in $script:SharedDirs + $script:SharedFiles) { $ex += $acc.Dir + "/" + $s }
  }
  return $ex
}

function Invoke-Tar {
  param([string[]]$Argv, [long]$Total, [string]$Label)
  $log = Join-Path $env:LOCALAPPDATA ("Temp\opencode\claude-tar-" + [guid]::NewGuid().ToString("N") + ".log")
  $quoted = @("-v") + $Argv | ForEach-Object { if ($_ -match "^-") { $_ } else { '"' + $_ + '"' } }
  $p = Start-Process -FilePath $script:Tar -ArgumentList $quoted -NoNewWindow -PassThru -RedirectStandardError $log
  try { $p.PriorityClass = "BelowNormal" } catch {}
  Wait-Tar $p $log $Total $Label
  $warn = @(Read-TarLog $log | Where-Object { $_ -notmatch "^[ax] " })
  if (Test-Path -LiteralPath $log) { Remove-Item -LiteralPath $log -Force }
  return $warn
}

function Save-Accounts {
  param([string]$Tag = "", $Accs = $null)
  if ($Accs -eq $null) { $Accs = @(Get-Accounts) }
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $name = "claude-comptes-" + $stamp
  if ($Tag) { $name = "claude-comptes-" + $Tag + "-" + $stamp }
  $zip = Join-Path (Get-DownloadsDir) ($name + ".zip")
  $argv = @("-a", "-c", "-f", $zip, "-C", $env:USERPROFILE)
  $ex = @(Get-SaveExcludes $Accs)
  foreach ($x in $ex) { $argv += @("--exclude", $x) }
  $items = @(Get-SaveItems $Accs)
  $argv += $items
  $label = "sauvegarde"
  if ($Tag) { $label = "copie de l'etat actuel" }
  $warn = Invoke-Tar $argv (Measure-Entries $items $ex) $label
  if (-not (Test-Path -LiteralPath $zip)) { throw ("echec tar : " + ($warn -join " ")) }
  $mb = [math]::Round((Get-Item -LiteralPath $zip).Length / 1MB)
  $res = $zip + " (" + $mb + " Mo, " + (@($Accs | ForEach-Object { $_.Label }) -join ", ") + ")"
  if ($warn.Count -gt 0) { $res += ", " + $warn.Count + " avertissement(s)" }
  return $res
}

function Get-Backups {
  return @(Get-ChildItem -LiteralPath (Get-DownloadsDir) -Filter "claude-comptes-*.zip" -File | Sort-Object LastWriteTime -Descending)
}

function Get-ZipAccounts {
  param([string]$Zip)
  $dirs = @(& $script:Tar -tf $Zip | ForEach-Object { ($_ -split "/")[0] } | Where-Object { $_ -match "^\.claude(-[^.]+)?$" } | Sort-Object -Unique)
  $reg = @()
  try { $reg = @((& $script:Tar -xOf $Zip ".claude-accounts.json" 2>$null | Out-String) | ConvertFrom-Json | ForEach-Object { $_ }) } catch {}
  $out = @()
  foreach ($d in $dirs) {
    $hit = @($reg | Where-Object { $_.Dir -eq $d })
    $label = $d
    if ($hit.Count -gt 0) { $label = $hit[0].Label }
    elseif ($d -eq ".claude") { $label = "compte1" }
    $out += [PSCustomObject]@{ Label = $label; Dir = $d }
  }
  return $out
}

function Restore-Accounts {
  param([string]$Zip, $Accs = $null)
  if ($Accs -eq $null) { $Accs = @(Get-ZipAccounts $Zip) }
  $current = @(Get-Accounts)
  $present = @($current | Where-Object { $d = $_.Dir; @($Accs | Where-Object { $_.Dir -eq $d }).Count -gt 0 })
  $safety = ""
  if ($present.Count -gt 0) { $safety = Save-Accounts "avant-restauration" $present }
  $entries = @(& $script:Tar -tf $Zip | ForEach-Object { ($_ -split "/")[0] })
  $top = @($entries | Sort-Object -Unique)
  $items = @(Get-AccountItems $Accs | Where-Object { $top -contains $_ })
  $total = @($entries | Where-Object { $items -contains $_ }).Count
  $script:Sizes = @{}
  $warn = Invoke-Tar (@("-x", "-f", $Zip, "-C", $env:USERPROFILE) + $items) $total "restauration"
  $added = @($Accs | Where-Object { $d = $_.Dir; @($current | Where-Object { $_.Dir -eq $d }).Count -eq 0 })
  if ($added.Count -gt 0) { Save-Registry (@($current) + $added) }
  foreach ($acc in Get-Accounts) { Repair-SharedLinks $acc -Force }
  $res = "restaure : " + (@($Accs | ForEach-Object { $_.Label }) -join ", ")
  if ($safety) { $res += ". Etat precedent garde dans " + (Split-Path ($safety -replace " \(.*$", "") -Leaf) }
  if ($warn.Count -gt 0) { $res += ", " + $warn.Count + " fichier(s) non restaure(s), en cours d'utilisation ?" }
  return $res
}
