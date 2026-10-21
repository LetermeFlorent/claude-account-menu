. (Join-Path $PSScriptRoot "claude-web-server.ps1")
. (Join-Path $PSScriptRoot "claude-web-state.ps1")
. (Join-Path $PSScriptRoot "claude-web-lists.ps1")
. (Join-Path $PSScriptRoot "claude-web-actions.ps1")
$script:WebOpen = $false
$script:WebReopen = $false
$script:WebFlag = "--web"

function Open-MenuWeb {
  param($State)
  try { $null = Start-WebServer @{ state = { Get-WebState $script:WebOpen }; prefs = { Get-WebPrefs }; backups = { Get-WebBackups } } }
  catch {
    $State.Msg = @(("  page web impossible : " + $_.Exception.Message), $script:Ink.Alert)
    $State.Dirty = $true
    return
  }
  $script:UiPoll = { Receive-WebRequests $script:WebOpen }
  $url = Get-WebUrl
  $null = Open-Browser $url
  $State.Msg = @(("  page web : " + $url), $script:Levels["7d"][0])
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
