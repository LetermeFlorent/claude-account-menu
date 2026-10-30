. Import-ClmModule claude-display, claude-text, claude-web-look
$script:WebUsagePollMin = 15
$script:WebUsagePollMax = 600

function Invoke-WebDisplay {
  param($Data)
  $values = [ordered]@{}
  foreach ($k in @("palette", "anim")) { if (Get-WebText $Data $k) { $values[$k] = Get-WebText $Data $k } }
  $null = Set-DisplayValues $values
  Update-UiDisplay
  $script:MenuState.Dirty = $true
  return New-WebDone (Get-ClmText "server.displaySaved")
}

function Get-WebLookChoice {
  param($Data, [string]$Name, [string[]]$Allowed, [string]$Refused)
  $v = Get-WebText $Data $Name
  if ($v -and $Allowed -cnotcontains $v) { throw (Get-ClmText $Refused $v) }
  return $v
}

function Invoke-WebLook {
  param($Data)
  $values = [ordered]@{}
  $lang = Get-WebLookChoice $Data "lang" $script:DisplayLangs "server.unknownLang"
  $theme = Get-WebLookChoice $Data "theme" $script:DisplayWebThemes "server.unknownTheme"
  if ($lang) { $values.lang = $lang }
  if ($theme) { $values.webTheme = $theme }
  if ($values.Count -gt 0) { $null = Set-DisplayValues $values }
  Clear-WebSystemLook
  return New-WebDone "" (Get-WebLook)
}

function Invoke-WebUsagePoll {
  param($Data)
  $text = Get-WebText $Data "seconds"
  $range = [ordered]@{ seconds = 0; min = $script:WebUsagePollMin; max = $script:WebUsagePollMax }
  if ($text -eq "") { $range.seconds = [int](Read-UsagePollSeconds); return New-WebDone "" $range }
  if ($text -notmatch '^[0-9]{1,4}$' -or [int]$text -lt $range.min -or [int]$text -gt $range.max) { throw (Get-ClmText "server.badUsagePoll" @($text, $range.min, $range.max)) }
  $null = Set-DisplayUsagePoll ([int]$text)
  $range.seconds = [int](Read-UsagePollSeconds)
  return New-WebDone (Get-ClmText "server.usagePollSaved" @($range.seconds)) $range
}
