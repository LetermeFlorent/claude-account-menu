if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-menu-archive.ps1")) { . (Join-Path $PSScriptRoot "claude-menu-archive.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-self-version.ps1")) { . (Join-Path $PSScriptRoot "claude-self-version.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-machine-settings.ps1")) { . (Join-Path $PSScriptRoot "claude-machine-settings.ps1") }
if ($null -eq $script:ClmOnce -or $script:ClmOnce.Add("claude-registry.ps1")) { . (Join-Path $PSScriptRoot "claude-registry.ps1") }
$script:SaveExcludes = @("cache", "paste-cache", "session-env", "shell-snapshots", "ide", "*.lock", ".local/bin/*.exe") + $script:SkipConversations
$script:ArchiveRegistryName = ".claude-accounts.json"

function Get-AccountItems {
  param($Accs)
  $names = @()
  foreach ($a in @(Select-ValidAccounts $Accs)) {
    $names += $a.Dir
    if ($a.Dir -eq ".claude") { $names += @(".claude.json", ".mcp.json") }
  }
  return $names
}

function Get-SaveItems {
  param($Accs)
  $h = $script:HomeDir
  $bin = Get-ChildItem -LiteralPath $PSScriptRoot -File | Where-Object { $_.Name -match "^((clm|claude-.*)\.(cmd|ps1)|clm|clm\.version)$" } | ForEach-Object { ".local/bin/" + $_.Name }
  $names = @(Get-AccountItems $Accs) + @($bin)
  return @($names | Where-Object { Test-Path -LiteralPath (Join-Path $h $_) })
}

function New-RegistryStage {
  if (-not (Test-Path -LiteralPath $script:RegistryPath)) { return $null }
  $dir = Join-Path ([IO.Path]::GetTempPath()) ("claude-reg-" + [guid]::NewGuid().ToString("N"))
  $null = [IO.Directory]::CreateDirectory($dir)
  [IO.File]::Copy($script:RegistryPath, (Join-Path $dir $script:ArchiveRegistryName))
  return $dir
}

function Get-SaveExcludes {
  param($Accs)
  $ex = @($script:SaveExcludes)
  foreach ($acc in @(Select-ValidAccounts $Accs)) {
    $ex += $acc.Dir + "/skills/.*"
    if ($acc.Dir -eq ".claude") { continue }
    foreach ($s in $script:SharedDirs + $script:SharedFiles) { $ex += $acc.Dir + "/" + $s }
  }
  return $ex
}

function Get-FreeArchivePath {
  param([string]$Name, [string]$Ext)
  $dir = Get-DownloadsDir
  $path = Join-Path $dir ($Name + $Ext)
  for ($n = 2; Test-Path -LiteralPath $path; $n++) { $path = Join-Path $dir ($Name + "-" + $n + $Ext) }
  return $path
}

function Save-Accounts {
  param([string]$Tag = "", $Accs = $null)
  if ($null -eq $Accs) { $Accs = @(Get-Accounts) }
  Initialize-Tar
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $name = "claude-comptes-" + $stamp
  if ($Tag) { $name = "claude-comptes-" + $Tag + "-" + $stamp }
  $zip = Get-FreeArchivePath $name (Get-ArchiveExtension $script:TarFlavor)
  $argv = @("-a", "-c", "-f", $zip, "-C", $script:HomeDir)
  $ex = @(Get-SaveExcludes $Accs)
  foreach ($x in $ex) { $argv += @("--exclude", $x) }
  $items = @(Get-SaveItems $Accs)
  $argv += $items
  $label = "sauvegarde"
  if ($Tag) { $label = "copie de l'etat actuel" }
  $stage = New-RegistryStage
  if ($stage) { $argv += @("-C", $stage, $script:ArchiveRegistryName) }
  try { $warn = Invoke-Tar $argv (Measure-Entries $items $ex) $label }
  finally { if ($stage) { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue } }
  if (-not (Test-Path -LiteralPath $zip)) { throw ("echec tar : " + ($warn -join " ")) }
  if ($warn.Count -gt 0 -and -not (Test-ArchiveIntact $zip)) {
    Remove-Item -LiteralPath $zip -Force
    throw ("sauvegarde illisible, effacee : " + (@($warn | Select-Object -First 3) -join " "))
  }
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
  $dirs = @(& $script:Tar -tf $Zip | ForEach-Object { ($_ -split "/")[0] } | Where-Object { Test-AccountDir $_ } | Sort-Object -Unique)
  $reg = @()
  try { $reg = @(((& $script:Tar -xOf $Zip $script:ArchiveRegistryName 2>$null | Out-String) -replace "^[^\[\{]*", "") | ConvertFrom-Json | ForEach-Object { $_ }) } catch { Write-Verbose $_.Exception.Message }
  $out = @()
  foreach ($d in $dirs) {
    $hit = @($reg | Where-Object { $_.Dir -eq $d })
    $label = $d
    if ($hit.Count -gt 0 -and (ConvertTo-AccountLabel $hit[0].Label)) { $label = ConvertTo-AccountLabel $hit[0].Label }
    elseif ($d -eq ".claude") { $label = "compte1" }
    $out += [PSCustomObject]@{ Label = $label; Dir = $d }
  }
  return $out
}

function Restore-Accounts {
  param([string]$Zip, $Accs = $null)
  Assert-ArchiveReadable $Zip
  Assert-BackupVersion $Zip
  if ($null -eq $Accs) { $Accs = @(Get-ZipAccounts $Zip) }
  $Accs = @(Select-ValidAccounts $Accs)
  $entries = @(& $script:Tar -tf $Zip | ForEach-Object { ($_ -split "/")[0] })
  $top = @($entries | Sort-Object -Unique)
  $Accs = @($Accs | Where-Object { $top -contains $_.Dir })
  if ($Accs.Count -eq 0) { throw "aucun compte a restaurer dans cette sauvegarde" }
  $items = @(Get-AccountItems $Accs | Where-Object { $top -contains $_ })
  $links = @(Get-TarLinkRoots @(& $script:Tar -tvf $Zip))
  foreach ($i in $items) {
    if ($links -contains $i) { throw ("sauvegarde refusee : " + $i + " y est un lien") }
    if (Test-ReparsePath (Join-Path $script:HomeDir $i)) { throw ("restauration refusee : " + $i + " est un lien sur ce PC") }
  }
  $current = @(Get-Accounts)
  $present = @($current | Where-Object { $d = $_.Dir; @($Accs | Where-Object { $_.Dir -eq $d }).Count -gt 0 })
  $safety = ""
  if ($present.Count -gt 0) { $safety = Save-Accounts "avant-restauration" $present }
  $total = @($entries | Where-Object { $items -contains $_ }).Count
  $script:Sizes = @{}
  $machine = Get-MachineSnapshot @($Accs | ForEach-Object { Join-Path (Get-AccountPath $_) "settings.json" }) (Join-Path (Join-Path $script:HomeDir ".claude") "settings.json")
  $warn = Invoke-Tar (@("-x", "-f", $Zip, "-C", $script:HomeDir) + $items) $total "restauration"
  Restore-MachineSnapshot $machine
  $added = @($Accs | Where-Object { $d = $_.Dir; @($current | Where-Object { $_.Dir -eq $d }).Count -eq 0 })
  if ($added.Count -gt 0) { Save-Registry (@($current) + $added) }
  foreach ($acc in Get-Accounts) { Repair-SharedLinks $acc -Force }
  $res = "restaure : " + (@($Accs | ForEach-Object { $_.Label }) -join ", ")
  if ($safety) { $res += ". Etat precedent garde dans " + [regex]::Match($safety, '[^\\/]+?\.(zip|tar\.gz)(?= \()').Value }
  if ($warn.Count -gt 0) { $res += ", " + $warn.Count + " fichier(s) non restaure(s), en cours d'utilisation ?" }
  return $res
}
