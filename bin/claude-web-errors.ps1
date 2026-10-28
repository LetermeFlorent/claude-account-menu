$script:WebErrorText = "erreur de clm"
$script:WebErrorWhere = ", detail dans le terminal"
$script:WebLastDetail = ""
$script:WebPathChars = New-Object regex '[\\/]'

function Write-WebDetail {
  param([string]$Text)
  $script:WebLastDetail = $Text
  if ($null -eq $script:MenuState) { return }
  $ink = $null
  if ($null -ne $script:Ink) { $ink = $script:Ink.Alert }
  $script:MenuState.Msg = @(("  page web, " + $Text), $ink)
  $script:MenuState.Dirty = $true
}

function Get-WebHiddenText {
  param($Err, [string]$Code)
  $label = $script:WebErrorText + " (" + $Code + ")"
  Write-WebDetail ($label + " : " + [string]$Err.Exception.Message)
  return $label + $script:WebErrorWhere
}

function Get-WebErrorText {
  param($Err, [string]$Code)
  $msg = [string]$Err.Exception.Message
  if ($Err.Exception.GetType() -eq [Management.Automation.RuntimeException] -and -not $script:WebPathChars.IsMatch($msg)) { return $msg }
  return Get-WebHiddenText $Err $Code
}
