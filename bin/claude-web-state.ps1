. Import-ClmModule claude-web-look

function Get-WebQuota {
  param($Pct, $Pace, [string]$Left)
  $q = [ordered]@{ pct = $null; left = $Left; pace = ""; tone = "dim" }
  if ($null -ne $Pct -and "" + $Pct -ne "") { $q.pct = [int][math]::Round([double]$Pct) }
  if ($null -ne $Pace) { $q.pace = $Pace.Text; $q.tone = $Pace.Tone }
  return $q
}

function Get-WebAccount {
  param($Entry, [int]$Index, [int]$Sel)
  $u = $Entry.U
  $v = Get-UsageView $u
  $err = $null
  if ($u.Error) { $err = [string]$u.Error }
  return [ordered]@{
    n = $Index + 1; label = [string]$Entry.Acc.Label; dir = [string]$Entry.Acc.Dir; email = [string]$u.Email; plan = [string]$u.Plan
    pending = [bool]$Entry.Pending; seen = [bool]$Entry.Seen; error = $err; badge = $v.Badge; note = $v.Note; away = (Get-AccountAway $Entry.Acc)
    erasable = (Test-ErasableDir $Entry.Acc.Dir); selected = ($Index -eq $Sel)
    q5 = (Get-WebQuota $u.Pct5 $v.Pace5 $v.Left5); q7 = (Get-WebQuota $u.Pct7 $v.Pace7 $v.Left7)
  }
}

function Get-WebDrive {
  $job = $script:DriveJob
  $d = [ordered]@{ connected = $false; pc = ""; auto = $false; tag = ""; running = $false; failed = $false }
  if ($null -eq $job -or -not $job.Connected) { return $d }
  $d.connected = $true
  $d.pc = Get-DrivePcName
  $d.auto = Test-DriveAuto
  $d.tag = [string](Get-DriveTag $job)[0]
  $d.running = [bool](Test-DriveJobRunning $job)
  $d.failed = [bool]$job.Failed
  return $d
}

function Get-WebDisplay {
  $d = Read-DisplayConfig
  $f = Get-DisplayForced
  return [ordered]@{ palette = $d.palette; anim = $d.anim; paletteEnv = $f.palette; animEnv = $f.anim }
}

function Get-WebTone {
  param($Ink)
  $rgb = @($Ink) -join ","
  if ($rgb -eq ($script:Levels["7d"][0] -join ",")) { return "ok" }
  foreach ($p in $script:Palettes.Values) { if ($rgb -eq ($p.Alert -join ",")) { return "alert" } }
  return "dim"
}

function Get-WebUpdate {
  $u = [ordered]@{ ready = [bool](Test-ClmUpdateReady); latest = "" }
  if ($u.ready) { try { $u.latest = Get-ClmName $script:ClmCheck.Latest } catch { $u.latest = "" } }
  return $u
}

function Get-WebState {
  param([bool]$Open)
  $st = $script:MenuState
  $accs = New-Object 'System.Collections.Generic.List[object]'
  $msg = [ordered]@{ text = ""; tone = "dim" }
  $version = ""
  if ($null -ne $st) {
    for ($i = 0; $i -lt $st.Entries.Count; $i++) { $accs.Add((Get-WebAccount $st.Entries[$i] $i $st.Sel)) }
    if ($st.Msg) { $msg.text = ([string]$st.Msg[0]).Trim(); $msg.tone = Get-WebTone $st.Msg[1] }
    $version = [string]$st.Version
  }
  return [ordered]@{
    ok = $true; open = $Open; startup = ($null -ne $script:Startup -and (Test-StepsLeft $script:Startup @())); version = $version
    update = (Get-WebUpdate); msg = $msg; accounts = $accs.ToArray(); drive = (Get-WebDrive); display = (Get-WebDisplay); look = (Get-WebLook)
  }
}
