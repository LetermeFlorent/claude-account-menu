$script:WebBackupMax = 30

function Get-WebPrefLine {
  param($Line)
  if ($Line.Head -and $Line.Sub) { return [ordered]@{ type = "sub"; label = $Line.Label } }
  if ($Line.Head) { return [ordered]@{ type = "head"; label = $Line.Label } }
  return [ordered]@{
    type = "item"; id = (Get-PrefsId $Line); kind = $Line.Kind; label = $Line.Label; tag = [string]$Line.Tag
    on = [bool]$Line.On; mixed = [bool]$Line.Mixed; all = [bool]$Line.All; erasing = [bool]$Line.Erasing; wait = [bool]$Line.Wait
  }
}

function Get-WebPcPrefs {
  param($Prefs, [string]$Me, [string]$Pc)
  $out = [ordered]@{ name = $Pc; ready = [bool](Test-PcReachable $Prefs.Catalog $Pc); sub = (Get-PcPrefsSub $Prefs.Catalog $Pc); lines = @() }
  $out.lines = @(foreach ($l in (Get-PcPrefsLines $Prefs.Choice $Prefs.Catalog $Me $Pc)) { Get-WebPrefLine $l })
  return $out
}

function Get-WebPrefs {
  $out = [ordered]@{ ok = $true; connected = [bool](Test-DriveConnected); sub = ""; warn = [ordered]@{}; lines = @(); me = ""; pcs = @() }
  foreach ($k in $script:PrefsEraseWarn.Keys) { $out.warn[$k] = $script:PrefsEraseWarn[$k].Trim() }
  if (-not $out.connected) { return $out }
  $p = Read-CliPrefs
  $out.sub = Get-PrefsSub $p.Catalog
  $out.lines = @(foreach ($l in $p.Lines) { Get-WebPrefLine $l })
  $out.me = Get-DrivePcName
  $names = Get-PrefsPcs $p.Catalog $out.me
  $out.pcs = @(for ($i = 1; $i -lt $names.Count; $i++) { Get-WebPcPrefs $p $out.me $names[$i] })
  return $out
}

function Get-WebBackups {
  $list = @(Get-Backups | Select-Object -First $script:WebBackupMax)
  $items = @(foreach ($f in $list) { [ordered]@{ name = $f.Name; date = $f.LastWriteTime.ToString("dd/MM/yyyy HH:mm"); mb = [math]::Round($f.Length / 1MB, 1) } })
  return [ordered]@{ ok = $true; dir = (Get-DownloadsDir); items = $items }
}

function Find-WebBackup {
  param([string]$Name)
  $hit = @(Get-Backups | Where-Object { $_.Name -ceq $Name })
  if ($hit.Count -eq 0) { throw ("sauvegarde introuvable : " + $Name) }
  return $hit[0].FullName
}

function Get-WebBackupAccounts {
  param([string]$Name)
  $zip = Find-WebBackup $Name
  Assert-BackupVersion $zip
  return @(foreach ($a in @(Get-ZipAccounts $zip)) { [ordered]@{ label = [string]$a.Label; dir = [string]$a.Dir } })
}
