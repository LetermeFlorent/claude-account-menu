. Import-ClmModule claude-web-server, claude-web-state, claude-web-lists, claude-web-actions, claude-text
$script:WebOpen = $false
$script:WebReopen = $false
$script:WebFlag = "--web"

function Open-MenuWeb {
  param($State)
  try { $null = Start-WebServer @{ state = { Get-WebState $script:WebOpen }; prefs = { Get-WebPrefs }; backups = { Get-WebBackups } } }
  catch {
    $State.Msg = @(("  " + (Get-ClmText "web.menu.failed" $_.Exception.Message)), $script:Ink.Alert)
    $State.Dirty = $true
    return
  }
  $script:UiPoll = { Receive-WebRequests $script:WebOpen }
  $url = New-WebUrl
  $null = Open-Browser $url
  $State.Msg = @(("  " + (Get-ClmText "web.menu.url" $url)), $script:Levels["7d"][0])
  $State.Dirty = $true
}

function Close-MenuWeb {
  $script:UiPoll = $null
  if ($null -ne $script:Web) { $script:WebReopen = $true }
  $script:WebOpen = $false
  Stop-WebServer
}

function Get-WebRestartArgs {
  param([object[]]$Argv)
  $list = [string[]]@($Argv | ForEach-Object { [string]$_ })
  if (-not $script:WebReopen -or $list -contains $script:WebFlag) { return ,$list }
  return ,[string[]]($list + $script:WebFlag)
}
