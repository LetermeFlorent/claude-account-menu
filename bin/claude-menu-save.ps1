. (Join-Path $PSScriptRoot "claude-menu-archive.ps1")
$script:SaveExcludes = @("cache", "paste-cache", "session-env", "shell-snapshots", "ide", "*.lock", ".local/bin/*.exe")

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
  $h = $script:HomeDir
  $bin = Get-ChildItem -LiteralPath $PSScriptRoot -File | Where-Object { $_.Name -match "^((clm|claude-.*)\.(cmd|ps1)|clm)$" } | ForEach-Object { ".local/bin/" + $_.Name }
  $names = @(Get-AccountItems $Accs) + @(".claude-accounts.json") + @($bin)
  return @($names | Where-Object { Test-Path -LiteralPath (Join-Path $h $_) })
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

function Save-Accounts {
  param([string]$Tag = "", $Accs = $null)
  if ($Accs -eq $null) { $Accs = @(Get-Accounts) }
  Initialize-Tar
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $name = "claude-comptes-" + $stamp
  if ($Tag) { $name = "claude-comptes-" + $Tag + "-" + $stamp }
  $zip = Join-Path (Get-DownloadsDir) ($name + (Get-ArchiveExtension $script:TarFlavor))
  $argv = @("-a", "-c", "-f", $zip, "-C", $script:HomeDir)
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
  return @(Get-ChildItem -LiteralPath (Get-DownloadsDir) -File | Where-Object { $_.Name -like "claude-comptes-*.zip" -or $_.Name -like "claude-comptes-*.tar.gz" } | Sort-Object LastWriteTime -Descending)
}

function Get-ZipAccounts {
  param([string]$Zip)
  Assert-ArchiveReadable $Zip
  $dirs = @(& $script:Tar -tf $Zip | ForEach-Object { ($_ -split "/")[0] } | Where-Object { $_ -match "^\.claude(-[^.]+)?$" } | Sort-Object -Unique)
  $reg = @()
  try { $reg = @(((& $script:Tar -xOf $Zip ".claude-accounts.json" 2>$null | Out-String) -replace "^[^\[\{]*", "") | ConvertFrom-Json | ForEach-Object { $_ }) } catch {}
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
  Assert-ArchiveReadable $Zip
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
  $warn = Invoke-Tar (@("-x", "-f", $Zip, "-C", $script:HomeDir) + $items) $total "restauration"
  $added = @($Accs | Where-Object { $d = $_.Dir; @($current | Where-Object { $_.Dir -eq $d }).Count -eq 0 })
  if ($added.Count -gt 0) { Save-Registry (@($current) + $added) }
  foreach ($acc in Get-Accounts) { Repair-SharedLinks $acc -Force }
  $res = "restaure : " + (@($Accs | ForEach-Object { $_.Label }) -join ", ")
  if ($safety) { $res += ". Etat precedent garde dans " + (Split-Path ($safety -replace " \(.*$", "") -Leaf) }
  if ($warn.Count -gt 0) { $res += ", " + $warn.Count + " fichier(s) non restaure(s), en cours d'utilisation ?" }
  return $res
}
