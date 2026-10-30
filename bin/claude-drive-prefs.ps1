. Import-ClmModule claude-mcp-globals, claude-drive-asks

function Start-SyncPrefs {
  param($Setup)
  $Folders = $Setup.Folders; $Presence = $Setup.Presence; $Pc = [string]$Setup.Pc
  $Accs = $Setup.Accs; $Res = $Setup.Res; $Keys = $Setup.Keys
  $prefs = @{ Folders = $Folders; Presence = $Presence; Pc = $Pc; Catalog = (Read-SyncCatalog); Choice = (Read-SyncChoice); Keys = $Keys }
  $prefs.Catalog.Waiting = Get-WaitingPcs $Presence $script:McpFormat
  $script:McpPerPc = $prefs.Catalog.Waiting.Count -eq 0
  $prefs.Catalog.PerPc = $script:McpPerPc
  Update-PcFiles $prefs.Catalog $Presence $Keys $Res
  $prefs.Sent = Get-OwnPcText $prefs.Catalog $Pc
  Receive-PcAsks $prefs
  Update-OwnAsks $prefs
  Set-OwnPcChoice $prefs
  if ($script:McpPerPc) {
    $Res.Failed += [int](Sync-McpPrefs $prefs $Accs)
    $Res.Failed += [int](Sync-GlobalMcp $prefs $Accs)
  }
  Set-OwnPcChoice $prefs
  Save-OwnPcFile $prefs $prefs.Sent
  Save-SyncCatalog $prefs.Catalog
  $prefs.Excludes = Get-SkillExcludes $prefs.Choice
  $prefs.Erased = Get-ErasedSkills $prefs.Catalog.Pcs
  return $prefs
}

function Complete-SyncPrefs {
  param($Prefs, $Listing, $Ctl, [long]$DeadlineMs)
  $before = Get-OwnPcText $Prefs.Catalog $Prefs.Pc
  $skillsErased = Update-SkillPrefs @{ Choice = $Prefs.Choice; Catalog = $Prefs.Catalog; Me = $Prefs.Pc; Listing = $Listing; Ctl = $Ctl; DeadlineMs = $DeadlineMs }
  if ($skillsErased.Count -gt 0) {
    Add-ErasedSkills $Prefs.Catalog $Prefs.Pc $skillsErased
    Save-OwnPcFile $Prefs $before
    $Prefs.Choice = Update-SyncChoice { param($c) Remove-EraseRequests $c "skills" $skillsErased }
  }
  $Prefs.Catalog.Skills = Get-DriveSkillNames $Listing
  $goneSkills = Get-GoneOffSkills $Prefs.Choice $Prefs.Catalog.Skills
  if ($goneSkills.Count -gt 0) { $Prefs.Choice = Update-SyncChoice { param($c) foreach ($n in $goneSkills) { $null = $c.skills.Remove($n) } } }
  Save-SyncCatalog $Prefs.Catalog
}
