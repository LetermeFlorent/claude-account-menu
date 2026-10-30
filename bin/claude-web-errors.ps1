. Import-ClmModule claude-text
$script:WebLastDetail = ""
$script:WebPathChars = New-Object regex '[\\/]'

function Write-WebDetail {
  param([string]$Text)
  $script:WebLastDetail = $Text
  if ($null -eq $script:MenuState) { return }
  $ink = $null
  if ($null -ne $script:Ink) { $ink = $script:Ink.Alert }
  $script:MenuState.Msg = @(("  " + (Get-ClmText "web.error.detail" $Text)), $ink)
  $script:MenuState.Dirty = $true
}

function Get-WebHiddenText {
  param($Err, [string]$Code)
  Write-WebDetail (Get-ClmText "web.error.clm" @($Code, [string]$Err.Exception.Message))
  return Get-ClmText "server.hiddenError" $Code
}

function Get-WebErrorText {
  param($Err, [string]$Code)
  $msg = [string]$Err.Exception.Message
  if ($Err.Exception.GetType() -eq [Management.Automation.RuntimeException] -and -not $script:WebPathChars.IsMatch($msg)) { return $msg }
  return Get-WebHiddenText $Err $Code
}
