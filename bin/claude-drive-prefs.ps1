. (Join-Path $PSScriptRoot "claude-mcp-globals.ps1")

function Start-SyncPrefs {
  param($Folders, $Presence, [string]$Pc, $Accs, $Res)
  $prefs = @{ Folders = $Folders; Presence = $Presence; Pc = $Pc; Catalog = (Read-SyncCatalog); Choice = (Read-SyncChoice) }
  $prefs.Catalog.Waiting = Get-WaitingPcs $Presence
  $script:McpPerPc = $prefs.Catalog.Waiting.Count -eq 0
  $prefs.Catalog.PerPc = $script:McpPerPc
  Update-PcFiles $prefs.Catalog $Presence
  if ($script:McpPerPc) {
    $Res.Failed += [int](Sync-McpPrefs $prefs $Accs)
    $Res.Failed += [int](Sync-GlobalMcp $prefs $Accs)
  }
  Save-SyncCatalog $prefs.Catalog
  $prefs.Excludes = Get-SkillExcludes $prefs.Choice
  $prefs.Erased = Get-ErasedSkills $prefs.Catalog.Pcs
  return $prefs
}

function Complete-SyncPrefs {
  param($Prefs, $Listing, $Ctl, [long]$DeadlineMs)
  $before = Get-OwnPcText $Prefs.Catalog $Prefs.Pc
  $skillsErased = Update-SkillPrefs $Prefs.Choice $Listing $Ctl $DeadlineMs
  if ($skillsErased.Count -gt 0) {
    Add-ErasedSkills $Prefs.Catalog $Prefs.Pc $skillsErased
    Save-OwnPcFile $Prefs $before
    $Prefs.Choice = Update-SyncChoice { param($c) Remove-EraseRequests $c "skills" $skillsErased }
  }
  $Prefs.Catalog.Skills = Get-DriveSkillNames $Listing
  Save-SyncCatalog $Prefs.Catalog
}
