. Import-ClmModule claude-text

function Get-MenuFailText {
  param([string]$Name, [string]$Detail)
  switch ($Name) {
    "add" { return "  " + (Get-ClmText "menu.loop.fail.add" @($Detail)) }
    "drivelogin" { return "  " + (Get-ClmText "menu.loop.fail.drive.login" @($Detail)) }
  }
  return "  " + $Detail
}
