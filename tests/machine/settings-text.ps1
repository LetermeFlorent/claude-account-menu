function New-SettingsText {
  param([string[]]$Members)
  return "{`n  " + ($Members -join ",`n  ") + "`n}`n"
}

function New-SeedHooksMember {
  param([string]$Command)
  return '"hooks": { "SessionStart": [{ "matcher": "startup", "hooks": [{ "type": "command", "command": ' + (ConvertTo-JsonString $Command) + ', "timeout": 15 }] }] }'
}
